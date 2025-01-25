-- lua/struml/init.lua
local config = require("struml.config")
local diagram = require("struml.diagram")

local M = {}

function M.setup(user_opts)
  local conf = config.merge(user_opts)
  M.config = conf

  -- Example: Autocommand to render diagrams on save for certain filetypes
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.dart", "*.go", "*.py", "*.rs", "*.js", "*.ts" },
    callback = function(args)
      diagram.render_diagrams_in_buffer(args.buf, conf)
    end,
  })

  -- A user command to manually invoke rendering
  vim.api.nvim_create_user_command("StrumlRender", function(opts)
    diagram.render_diagrams_in_buffer(nil, conf)
  end, { desc = "Render Struml diagrams in current buffer" })

  vim.notify("[Struml] Setup complete. Use :StrumlRender or just save your code", vim.log.levels.INFO)
end

return M
