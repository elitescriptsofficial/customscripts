const resource = 'EliteScripts_StaffPortal'

const ticketCategories = {
  admin: { label: 'Admin Tickets' },
  legal: { label: 'Legal Tickets' },
  gangs: { label: 'Gangs Tickets' },
  sales: { label: 'Sales Tickets' },
  pier: { label: 'Pier Team Tickets' },
}

function q(id){ return document.getElementById(id) }
const app = q('app')

q('close').addEventListener('click', ()=>{
  fetch(`https://${resource}/close`, { method: 'POST' })
})

q('createSupportTicket').addEventListener('click', ()=>{
  const description = q('ticketDescription').value.trim()
  const category = q('ticketCategory').value
  if (!description) return alert('Enter a brief description of what happened')
  fetch(`https://${resource}/createSupportTicket`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ description, category }) })
})

q('createRank').addEventListener('click', ()=>{
  const name = q('rankName').value.trim()
  if (!name) return alert('Enter rank name')
  const checked = Array.from(document.querySelectorAll('#permissionsContainer input[type=checkbox]:checked')).map(cb=>cb.value)
  fetch(`https://${resource}/createRank`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ name, permissions: checked }) })
})

q('assignBtn').addEventListener('click', ()=>{
  const identifier = q('assignIdentifier').value.trim()
  const rank = q('assignRank').value.trim()
  if (!identifier || !rank) return alert('Enter identifier and rank')
  fetch(`https://${resource}/assignRank`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ identifier, rank }) })
})

window.addEventListener('message', (event) => {
  const d = event.data
  if (!d) return
  if (d.action === 'open') {
    app.classList.remove('hidden')
    if (d.mode === 'staff') {
      openStaffView()
    } else {
      openTicketView()
    }
  } else if (d.action === 'close') {
    app.classList.add('hidden')
  } else if (d.action === 'update') {
    renderData(d.ranks, d.assignments, d.isAdmin, d.permissions || [])
  } else if (d.action === 'updateTickets') {
    renderTickets(d.tickets, d.categories, d.canViewAll)
  } else if (d.action === 'showPopup') {
    showPopup(d.ticket, d.cancelled)
  } else if (d.action === 'showFailure') {
    alert('Support Ticket: ' + (d.reason || 'An error occurred'))
  }
})

function openTicketView(){
  q('ticketMode').classList.remove('hidden')
  q('staffMode').classList.add('hidden')
  q('pageTitle').textContent = 'Support Ticket'
}

function openStaffView(){
  q('ticketMode').classList.add('hidden')
  q('staffMode').classList.remove('hidden')
  q('pageTitle').textContent = 'Staff Portal'
}

function renderData(ranks, assignments, isAdmin, permissions){
  const ranksList = q('ranksList')
  const assignList = q('assignList')
  ranksList.innerHTML = ''
  assignList.innerHTML = ''
  renderPermissions(permissions)
  for (const name in ranks){
    const li = document.createElement('li')
    li.textContent = name + ' => ' + (ranks[name].permissions || []).join(',')
    if (isAdmin){
      const del = document.createElement('button')
      del.textContent = 'Delete'
      del.addEventListener('click', ()=>{
        fetch(`https://${resource}/deleteRank`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ name }) })
      })
      li.appendChild(del)
    }
    ranksList.appendChild(li)
  }
  for (const id in assignments){
    const li = document.createElement('li')
    li.textContent = id + ' => ' + assignments[id]
    assignList.appendChild(li)
  }
}

function renderTickets(tickets, categories, canViewAll){
  const list = q('ticketsList')
  list.innerHTML = ''
  if (!Array.isArray(tickets) || tickets.length === 0) {
    list.textContent = 'No support tickets available.'
    return
  }
  tickets.sort((a,b) => a.id - b.id)
  for (const ticket of tickets){
    const li = document.createElement('li')
    li.innerHTML = `<strong>${categories && categories[ticket.category] ? categories[ticket.category].label : ticket.category}</strong>`
    const meta = document.createElement('div')
    meta.className = 'ticket-meta'
    meta.textContent = `#${ticket.id} • ${ticket.status} • ${ticket.identifier}`
    const desc = document.createElement('div')
    desc.className = 'ticket-desc'
    desc.textContent = ticket.description
    li.appendChild(meta)
    li.appendChild(desc)
    list.appendChild(li)
  }
}

function showPopup(ticket, cancelled){
  const popup = q('ticketPopup')
  q('popupTitle').textContent = cancelled ? 'Support Ticket Cancelled' : 'Support Ticket'
  q('popupText').textContent = cancelled ? 'Your support ticket has been cancelled.' : 'Someone will be with you soon.'
  q('popupSubtext').textContent = cancelled ? '' : 'Press F7 to cancel ticket'
  popup.classList.remove('hidden')
  setTimeout(() => popup.classList.add('hidden'), 7000)
}

function renderPermissions(permissions){
  const container = q('permissionsContainer')
  container.innerHTML = ''
  if (!permissions || permissions.length === 0) {
    container.textContent = 'No permissions registered.'
    return
  }
  permissions.sort()
  for (const p of permissions){
    const id = 'perm_' + p.replace(/[^a-z0-9]/gi,'_')
    const div = document.createElement('div')
    const cb = document.createElement('input')
    cb.type = 'checkbox'
    cb.id = id
    cb.value = p
    const label = document.createElement('label')
    label.htmlFor = id
    label.textContent = p
    div.appendChild(cb)
    div.appendChild(label)
    container.appendChild(div)
  }
}
