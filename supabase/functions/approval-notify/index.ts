import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import webpush from 'npm:web-push'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const vapidPublicKey = Deno.env.get('WEB_PUSH_PUBLIC_KEY') ?? ''
const vapidPrivateKey = Deno.env.get('WEB_PUSH_PRIVATE_KEY') ?? ''
const vapidSubject = Deno.env.get('WEB_PUSH_SUBJECT') ?? 'mailto:admin@example.com'

if (vapidPublicKey && vapidPrivateKey) {
  webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey)
}

async function upsertSubscription(admin: ReturnType<typeof createClient>, payload: {
  endpoint: string
  subscription: unknown
  userId: string
  userEmail: string
  userAgent: string
}) {
  const primaryWrite = await admin
    .from('approval_push_subscriptions')
    .upsert({
      endpoint: payload.endpoint,
      subscription: payload.subscription,
      user_id: payload.userId,
      user_email: payload.userEmail,
      user_agent: payload.userAgent,
      is_active: true,
      updated_at: new Date().toISOString(),
      last_used_at: new Date().toISOString(),
    }, { onConflict: 'endpoint' })

  if (!primaryWrite.error) {
    return
  }

  const message = JSON.stringify(primaryWrite.error)
  if (!message.includes('approval_push_subscriptions')) {
    throw primaryWrite.error
  }

  const existingLegacy = await admin
    .from('admin_approval_requests')
    .select('id')
    .eq('action', 'push-subscription')
    .eq('request_secret', payload.endpoint)
    .eq('allowed_email', payload.userEmail)
    .maybeSingle()

  if (existingLegacy.error) {
    throw existingLegacy.error
  }

  if (existingLegacy.data?.id) {
    const legacyUpdate = await admin
      .from('admin_approval_requests')
      .update({
        reason: JSON.stringify(payload.subscription),
        requester_user: payload.userId,
        requester_host: 'phone-pwa',
        status: 'approved',
        approved_by_email: payload.userEmail,
        expires_at: new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', existingLegacy.data.id)

    if (legacyUpdate.error) {
      throw legacyUpdate.error
    }

    return
  }

  const legacyWrite = await admin
    .from('admin_approval_requests')
    .insert({
      request_id: crypto.randomUUID(),
      request_secret: payload.endpoint,
      action: 'push-subscription',
      reason: JSON.stringify(payload.subscription),
      requester_host: 'phone-pwa',
      requester_user: payload.userId,
      allowed_email: payload.userEmail,
      status: 'approved',
      approved_by_email: payload.userEmail,
      expires_at: new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString(),
    })

  if (legacyWrite.error) {
    throw legacyWrite.error
  }
}

async function listSubscriptions(admin: ReturnType<typeof createClient>, userEmail: string) {
  const primaryRead = await admin
    .from('approval_push_subscriptions')
    .select('endpoint, subscription')
    .eq('user_email', userEmail)
    .eq('is_active', true)

  if (!primaryRead.error) {
    return primaryRead.data ?? []
  }

  const message = JSON.stringify(primaryRead.error)
  if (!message.includes('approval_push_subscriptions')) {
    throw primaryRead.error
  }

  const legacyRead = await admin
    .from('admin_approval_requests')
    .select('id, request_secret, reason')
    .eq('action', 'push-subscription')
    .eq('allowed_email', userEmail)
    .eq('status', 'approved')

  if (legacyRead.error) {
    throw legacyRead.error
  }

  const deduped = new Map<string, { endpoint: string; subscription: unknown; legacyId?: number }>()

  for (const entry of legacyRead.data ?? []) {
    try {
      deduped.set(entry.request_secret, {
        endpoint: entry.request_secret,
        subscription: JSON.parse(entry.reason ?? '{}'),
        legacyId: entry.id,
      })
    } catch {
    }
  }

  return [...deduped.values()]
}

async function deactivateSubscription(admin: ReturnType<typeof createClient>, endpoint: string, legacyId?: number) {
  const updatePrimary = await admin
    .from('approval_push_subscriptions')
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq('endpoint', endpoint)

  if (!updatePrimary.error) {
    return
  }

  const message = JSON.stringify(updatePrimary.error)
  if (!message.includes('approval_push_subscriptions')) {
    throw updatePrimary.error
  }

  if (legacyId) {
    const legacyUpdate = await admin
      .from('admin_approval_requests')
      .update({ status: 'expired', updated_at: new Date().toISOString() })
      .eq('id', legacyId)

    if (legacyUpdate.error) {
      throw legacyUpdate.error
    }
  }
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await request.json().catch(() => ({}))
    const action = body.action ?? ''

    const admin = createClient(supabaseUrl, serviceRoleKey)

    if (action === 'subscribe') {
      const authHeader = request.headers.get('Authorization') ?? ''
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      })

      const { data: userData, error: userError } = await userClient.auth.getUser()
      if (userError || !userData.user) {
        return Response.json({ error: 'Not signed in.' }, { status: 401, headers: corsHeaders })
      }

      const subscription = body.subscription
      if (!subscription?.endpoint) {
        return Response.json({ error: 'Missing push subscription.' }, { status: 400, headers: corsHeaders })
      }

      await upsertSubscription(admin, {
        endpoint: subscription.endpoint,
        subscription,
        userId: userData.user.id,
        userEmail: (userData.user.email ?? '').toLowerCase(),
        userAgent: request.headers.get('user-agent') ?? '',
      })

      return Response.json({ ok: true }, { headers: corsHeaders })
    }

    if (action === 'notify') {
      const requestId = body.requestId ?? ''
      const requestSecret = body.requestSecret ?? ''
      const approvalUrl = body.approvalUrl ?? ''
      const approvalAction = body.approvalAction ?? 'Approval request'

      if (!requestId || !requestSecret || !approvalUrl) {
        return Response.json({ error: 'Missing request payload.' }, { status: 400, headers: corsHeaders })
      }

      const { data: approvalRequest, error: approvalError } = await admin
        .from('admin_approval_requests')
        .select('allowed_email,status,action')
        .eq('request_id', requestId)
        .eq('request_secret', requestSecret)
        .maybeSingle()

      if (approvalError) throw approvalError
      if (!approvalRequest || approvalRequest.status !== 'pending') {
        return Response.json({ error: 'Approval request is not available.' }, { status: 404, headers: corsHeaders })
      }

      const subscriptions = await listSubscriptions(admin, (approvalRequest.allowed_email ?? '').toLowerCase())

      let sent = 0
      for (const entry of subscriptions ?? []) {
        try {
          await webpush.sendNotification(entry.subscription, JSON.stringify({
            title: 'Approval needed',
            body: approvalAction || approvalRequest.action || 'A privileged action needs your approval.',
            url: approvalUrl,
            tag: requestId,
          }))
          sent += 1
        } catch {
          await deactivateSubscription(admin, entry.endpoint, entry.legacyId)
        }
      }

      return Response.json({ ok: true, sent }, { headers: corsHeaders })
    }

    return Response.json({ error: 'Unsupported action.' }, { status: 400, headers: corsHeaders })
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : typeof error === 'object'
        ? JSON.stringify(error)
        : String(error)

    return Response.json({ error: message }, { status: 500, headers: corsHeaders })
  }
})
