self.addEventListener('install', (event) => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener('push', (event) => {
  let payload = {
    title: 'Morgan Toolbox approval needed',
    body: 'A privileged action needs your approval.',
    url: '/morgan-toolbox/',
  }

  try {
    payload = { ...payload, ...(event.data ? event.data.json() : {}) }
  } catch {
  }

  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: 'approval-icon.svg',
      badge: 'approval-icon.svg',
      tag: payload.tag || 'approval-request',
      requireInteraction: true,
      data: {
        url: payload.url || '/morgan-toolbox/',
      },
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const targetUrl = event.notification.data?.url || '/morgan-toolbox/'

  event.waitUntil((async () => {
    const windowClients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    for (const client of windowClients) {
      if ('focus' in client) {
        client.navigate(targetUrl)
        return client.focus()
      }
    }

    if (self.clients.openWindow) {
      return self.clients.openWindow(targetUrl)
    }
  })())
})
