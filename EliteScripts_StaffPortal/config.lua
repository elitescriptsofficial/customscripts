Config = {
  -- Replace this with your server's default admin identifier (e.g. a Steam identifier)
  -- Example: "steam:110000112345678"
  defaultAdmin = "replace_with_admin_identifier",

  -- path inside the resource where rank/assignment data is stored
  dataFile = "data/ranks.json",

  -- path to persist support ticket data
  ticketDataFile = "data/tickets.json",

  ticketCategories = {
    admin = { label = "Admin Tickets", permission = "support.admin", team = "Team" },
    legal = { label = "Legal Tickets", permission = "support.legal", team = "Legal Team" },
    gangs = { label = "Gangs Tickets", permission = "support.gangs", team = "Gangs Team" },
    sales = { label = "Sales Tickets", permission = "support.sales", team = "Sales Team" },
    pier = { label = "Pier Team Tickets", permission = "support.pier", team = "Pier Team" },
  },
}

-- Note: other scripts can call exports['EliteScripts_StaffPortal']:hasPermission(identifier, permission)
