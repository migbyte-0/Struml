-- lua/struml/diagram.lua
local config = require("struml.config")
local M = {}

-- We'll store a cache keyed by "diagram_text" -> "hash" => "path to rendered file" or "ASCII output"
local render_cache = {}

--------------------------------------------------------------------------------
-- Utility: compute a hash (md5) for a string
--------------------------------------------------------------------------------
local function md5(str)
  return vim.fn.sha256(str) -- or use :echo sha256
  -- For an actual MD5, you'd need a custom MD5 function or use lua's resty.md5
end

--------------------------------------------------------------------------------
-- Utility: Debug printing
--------------------------------------------------------------------------------
local function dbg(conf, msg)
  if conf.debug then
    vim.notify("[Struml debug] " .. msg, vim.log.levels.INFO)
  end
end

--------------------------------------------------------------------------------
-- Utility: run external commands
--------------------------------------------------------------------------------
local function run_cmd(command)
  local handle = io.popen(command)
  if not handle then
    return nil, "Failed to run command: " .. command
  end
  local result = handle:read("*a")
  local ok, _, code = handle:close()
  return result, code
end

--------------------------------------------------------------------------------
-- parse_diagrams(lines, conf) -> { { line_num=..., content="A->B->C" }, ... }
-- Checks each line against conf.comment_patterns
--------------------------------------------------------------------------------
function M.parse_diagrams(lines, conf)
  local results = {}
  for line_idx, line in ipairs(lines) do
    for _, pat in ipairs(conf.comment_patterns) do
      local match = line:match(pat)
      if match then
        table.insert(results, {
          line_num = line_idx,
          content = match,
        })
        break -- no need to check other patterns once matched
      end
    end
  end
  return results
end

--------------------------------------------------------------------------------
-- create_mermaid_text(diagram_spec) -> mermaid source
-- E.g. "A->B->C" => "flowchart LR\n A --> B --> C\n"
--------------------------------------------------------------------------------
function M.create_mermaid_text(diagram_spec)
  -- naive parse, splitted by "->"
  local nodes = {}
  for node in diagram_spec:gmatch("[^%-]+") do
    table.insert(nodes, node:match("^%s*(.-)%s*$")) -- trim
  end

  local lines = { "flowchart LR" }
  for i = 1, (#nodes - 1) do
    lines[#lines + 1] = string.format("  %s --> %s", nodes[i], nodes[i + 1])
  end
  return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- generate_png(mermaid_text, conf) -> path_to_png or nil, err
-- Writes mermaid_text to a temp file, calls mmdc -> .png
--------------------------------------------------------------------------------
local function generate_png(mermaid_text, conf)
  local tmp_in = vim.fn.tempname() .. ".mmd"
  local tmp_out = vim.fn.tempname() .. conf.output_ext

  -- Write mermaid_text to tmp_in
  local f = io.open(tmp_in, "w")
  if not f then
    return nil, "Cannot open temp file: " .. tmp_in
  end
  f:write(mermaid_text)
  f:close()

  -- Construct mmdc command
  -- e.g. "mmdc -i tmp_in -o tmp_out --scale 1"
  local args = { conf.cli.mmdc, "-i", tmp_in, "-o", tmp_out }
  vim.list_extend(args, conf.mmdc_args or {})

  local cmd_str = table.concat(args, " ")
  dbg(conf, "Running mermaid cmd: " .. cmd_str)
  local _, code = run_cmd(cmd_str)
  if code ~= 0 then
    return nil, "Mermaid CLI failed with exit code " .. tostring(code)
  end

  return tmp_out
end

--------------------------------------------------------------------------------
-- convert_png_to_ascii(path_to_png, conf) -> ascii_text or nil, err
--------------------------------------------------------------------------------
local function convert_png_to_ascii(path_to_png, conf)
  local args = { conf.cli.ascii_converter, path_to_png }
  vim.list_extend(args, conf.ascii_args or {})

  local cmd_str = table.concat(args, " ")
  dbg(conf, "Running ascii-image-converter: " .. cmd_str)
  local output, code = run_cmd(cmd_str)
  if code ~= 0 then
    return nil, "ascii-image-converter failed with exit code " .. tostring(code)
  end
  return output
end

--------------------------------------------------------------------------------
-- show_in_float(ascii_text) -> opens a floating window
--------------------------------------------------------------------------------
local function show_in_float(ascii_text)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local lines = {}
  for s in ascii_text:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.5)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    row = row,
    col = col,
    width = width,
    height = height,
  })
  vim.api.nvim_win_set_option(win, "wrap", true)
  vim.api.nvim_win_set_option(win, "linebreak", true)
end

--------------------------------------------------------------------------------
-- show_with_image_nvim(path_to_png)
-- Requires "image.nvim" installed
--------------------------------------------------------------------------------
local function show_with_image_nvim(path_to_png)
  local ok, image = pcall(require, "image")
  if not ok then
    vim.notify("[Struml] image.nvim not found. Install or switch to ascii mode", vim.log.levels.ERROR)
    return
  end

  -- We'll open a new floating window for the image
  image.display_image(path_to_png, {
    w = math.floor(vim.o.columns * 0.7),
    h = math.floor(vim.o.lines * 0.5),
    preserve_aspect_ratio = true,
    col = math.floor(vim.o.columns * 0.15),
    row = math.floor(vim.o.lines * 0.25),
    -- More config in image.nvim docs
  })
end

--------------------------------------------------------------------------------
-- render_single_diagram(diagram_text, conf) -> show in a float (ASCII or image)
--------------------------------------------------------------------------------
local function render_single_diagram(diagram_text, conf)
  local hash_val = md5(diagram_text)
  -- Check cache
  if render_cache[hash_val] then
    dbg(conf, "Cache hit for diagram: " .. diagram_text)
    -- Already have ASCII or PNG path. Just show it
    local cached = render_cache[hash_val]
    if conf.renderer == "ascii" then
      show_in_float(cached.ascii)
    else
      show_with_image_nvim(cached.png)
    end
    return
  end

  -- Not in cache => real generation
  local mermaid_src = M.create_mermaid_text(diagram_text)
  local png_path, err = generate_png(mermaid_src, conf)
  if not png_path then
    vim.notify("[Struml] Failed to generate PNG: " .. (err or ""), vim.log.levels.ERROR)
    return
  end
  if conf.renderer == "ascii" then
    local ascii_output, ascii_err = convert_png_to_ascii(png_path, conf)
    if not ascii_output then
      vim.notify("[Struml] ascii-image-converter failed: " .. (ascii_err or ""), vim.log.levels.ERROR)
      return
    end
    -- Show ASCII
    show_in_float(ascii_output)
    render_cache[hash_val] = { ascii = ascii_output, png = png_path }
  else
    -- Show image
    show_with_image_nvim(png_path)
    render_cache[hash_val] = { png = png_path }
  end
end

--------------------------------------------------------------------------------
-- M.render_diagrams_in_buffer
-- 1) parse lines
-- 2) for each diagram content: generate + show
--    depends on conf.display_mode ("separate" or "combined")
--------------------------------------------------------------------------------
function M.render_diagrams_in_buffer(bufnr, conf)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  conf = conf or config.defaults

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diagrams = M.parse_diagrams(lines, conf)

  if #diagrams == 0 then
    vim.notify("[Struml] No 'diagram:' comments found in this file", vim.log.levels.INFO)
    return
  end

  if conf.display_mode == "combined" then
    -- Combine all diagram specs into one mermaid text, then show as single PNG/ASCII
    -- Very naive approach: chain them as separate flowcharts
    local combined_text = {}
    table.insert(combined_text, "flowchart LR")
    for _, d in ipairs(diagrams) do
      local tmp_src = M.create_mermaid_text(d.content)
      -- skip the "flowchart LR" line from each partial snippet
      for line in tmp_src:gmatch("[^\r\n]+") do
        if not line:find("flowchart LR") then
          table.insert(combined_text, line)
        end
      end
    end
    local all_content = table.concat(combined_text, "\n")
    local hash_val = md5(all_content)
    if render_cache[hash_val] then
      local cached = render_cache[hash_val]
      if conf.renderer == "ascii" then
        show_in_float(cached.ascii)
      else
        show_with_image_nvim(cached.png)
      end
      return
    else
      local png_path, err = generate_png(all_content, conf)
      if not png_path then
        vim.notify("[Struml] Combined mermaid generation failed: " .. (err or ""), vim.log.levels.ERROR)
        return
      end
      if conf.renderer == "ascii" then
        local ascii_output, ascii_err = convert_png_to_ascii(png_path, conf)
        if not ascii_output then
          vim.notify("[Struml] ascii-image-converter failed: " .. (ascii_err or ""), vim.log.levels.ERROR)
          return
        end
        show_in_float(ascii_output)
        render_cache[hash_val] = { ascii = ascii_output, png = png_path }
      else
        show_with_image_nvim(png_path)
        render_cache[hash_val] = { png = png_path }
      end
    end
  else
    -- "separate": each diagram in its own floating window
    for _, d in ipairs(diagrams) do
      render_single_diagram(d.content, conf)
    end
  end
end

return M
