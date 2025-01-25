-- lua/struml/config.lua
local M = {}

--------------------------------------------------------------------------------
-- Default config table
--------------------------------------------------------------------------------
M.defaults = {
  -- Table of patterns to detect diagrams in a line.
  -- Each pattern should capture the actual diagram text in (.*)
  -- Example: `// diagram: flow`, `/// diagram: flow`, etc.
  comment_patterns = {
    "%s*//+%s*diagram:%s*(.*)", -- // diagram:
    -- Add more if needed, e.g. for # diagram:
    -- "%s*#%s*diagram:%s*(.*)",
  },

  -- Display mode for multiple diagrams in a single buffer:
  --   "separate": each diagram in its own floating window
  --   "combined": combine them all into one output buffer
  display_mode = "separate",

  -- The rendering approach:
  --   "ascii" -> generate PNG with Mermaid, then convert to ASCII
  --   "image" -> generate PNG with Mermaid, then display using image.nvim
  renderer = "ascii",

  -- Path to mermaid CLI tool (mmdc) & ascii-image-converter
  -- Adjust if they're in custom locations.
  cli = {
    mmdc = "mmdc",                             -- should be in your $PATH
    ascii_converter = "ascii-image-converter", -- also in $PATH
  },

  -- If 'renderer' == "image", we assume you have image.nvim installed,
  -- and we'll just call require("image").display_image(...) with the PNG
  -- in a floating window.

  -- If you want to pass extra command-line arguments to `mmdc` or ascii-image-converter:
  mmdc_args = { "--scale", "1" }, -- example
  ascii_args = { "-C", "-c" },    -- example
  -- e.g. if you want a transparent background or theme:
  -- mmdc_args = { "--backgroundColor", "transparent", "--theme", "dark" },

  -- File extension to generate for the rendered diagram (usually .png)
  output_ext = ".png",

  -- Whether to print debug info
  debug = false,
}

--------------------------------------------------------------------------------
-- Merge user config with defaults
--------------------------------------------------------------------------------
function M.merge(user_opts)
  local final = vim.deepcopy(M.defaults)
  if user_opts then
    for k, v in pairs(user_opts) do
      if type(v) == "table" and type(final[k]) == "table" then
        -- shallow merge
        for kk, vv in pairs(v) do
          final[k][kk] = vv
        end
      else
        final[k] = v
      end
    end
  end
  return final
end

return M
