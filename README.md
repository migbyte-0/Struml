<div style="display: flex; align-items: center;">
  <img src="https://github.com/migbyte-0/Struml/blob/main/migbyte.svg" alt="Done by migbyte" width="250" />
  <span style="margin-left: 10px; font-size: 20px; font-weight: 900;">
    Done by <span style="color: lightgreen;">Migbyte</span> Team
  </span>
</div>


# Struml
Structure + UML = Struml
Turn your inline code comments into glorious ASCII (or PNG) diagrams with Mermaid & Neovim.

```lua         _
       _( )_    S T R U M L
     .-       -.  Where code meets diagrams
    /           \
   |  .--. .--.  |
   | (    X    ) |  "Architect your code in the blink of an eye!"
    \   .--.   /
     '-._____.-'
         ( )
```

# Table of Contents
# Table of Contents
1. [Why Struml?](#why-struml)
2. [Features](#features)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Configuration](#configuration)
6. [Dependencies](#dependencies)
7. [Advanced Topics](#advanced-topics)
   * [Multiple Patterns](#multiple-patterns)
   * [Caching Details](#caching-details)
   * [Error Handling](#error-handling)
   * [Optional image.nvim Integration](#optional-imagenvim-integration)
8. [License](#license)



---



# Why Struml?
Because your code is more than just text! Sometimes you want a quick UML-esque flow or sequence or graph to illustrate the logic inside your source. Struml uses your inline comments, hunts for lines containing diagram: (or any custom pattern), and pops open a floating window with a diagram.

No more alt-tabbing to external diagram tools and forgetting to keep them updated. With Struml, you can maintain and visualize diagrams right where they belong—in your code.

# Features
## **Multiple Diagram Detection**

Place multiple diagram: comments in a file. Struml can either:

   * Show each diagram in its own floating window, or
   * Combine them all into a single mega-flowchart.
     
## **Powered by Mermaid**
We use the [Mermaid CLI (mmdc)](https://github.com/mermaid-js/mermaid-cli) to generate PNG images of your diagrams, meaning you get all of Mermaid's syntax possibilities.

## **ASCII or PNG**
   * **ASCII Mode**: We'll pipe that PNG into [ascii-image-converter](https://github.com/TheZoraiz/ascii-image-converter) and show it inside a floating buffer.
   * **Image Mode**: We'll display the PNG via [image.nvim](https://github.com/your-image-nvim-repo) in a floating window (actual rendered image!).
     
## **Flexible Syntax**
Out of the box, it detects lines like // diagram: flow or /// diagram: flow. You can easily add more patterns if you use # diagram: or -- diagram: or anything else.

## **Error Handling**
If any external command fails (like mmdc or ascii-image-converter), you’ll see a helpful error in Neovim instead of silent failures.

## **Caching**
If the same diagram text hasn’t changed, Struml skips re-rendering. We keep a small in-memory cache to speed things up.



---



# Installation:
using Lazy

```lua
 {
  "migbyte-0/struml.nvim", -- or your fork: "myfork/struml.nvim"
  config = function()
    require("struml").setup({
      -- Optional custom config
      display_mode = "separate",  -- or "combined"
      renderer = "ascii",         -- or "image"
      debug = false,              -- set to true for debug logs
      cli = {
        mmdc = "mmdc",
        ascii_converter = "ascii-image-converter",
      },
      mmdc_args = { "--theme", "dark" },
      ascii_args = { "-C", "-c" },
    })
  end
}
```

Alternatively, with packer:

```lua
use {
  "migbyte-0/struml.nvim",
  config = function()
    require("struml").setup({})
  end
}
```


---



# Usage

1. Add a diagram comment to your code. For example, in a Dart file:
```dart
// diagram: Login -> Home -> Profile

/// diagram: A->B->C->D

```

2. Save the file or run :StrumlRender in Neovim.
   * If display_mode = "separate", each diagram is displayed in a new floating window.
   * If display_mode = "combined", all detected diagrams get merged into one monstrous flowchart.
  
     
3. Enjoy the rendered ASCII diagram or actual PNG image (if renderer = "image").
```go
// diagram: Start -> Middle -> End

func main() {
  // ...
}
```

Upon saving (or :StrumlRender), watch a floating window pop up with your diagram. Magic!



---



# Configuration

All default settings live in `lua/strum/config.lua`. When calling `require("strum").setup(...)`, you can override any of these:

| Option                 | Default                                   | Description                                                                                     |
|------------------------|-------------------------------------------|-------------------------------------------------------------------------------------------------|
| `comment_patterns`     | `{ "%s*/+%s*diagram:%s*(.*)" }`          | Table of Lua patterns used to detect lines with diagram text.                                  |
| `display_mode`         | `"separate"`                             | Either `"separate"` (one float per diagram) or `"combined"` (all diagrams merged).             |
| `renderer`             | `"ascii"`                                | `"ascii"` uses ascii-image-converter, `"image"` uses [image.nvim](https://github.com/your-image-nvim-repo)                          |
| `cli.mmdc`             | `"mmdc"`                                 | Mermaid CLI executable name/path.                                                              |
| `cli.ascii_converter`  | `"ascii-image-converter"`                | ascii-image-converter executable name/path.                                                    |
| `mmdc_args`            | `{ "--scale", "1" }`                     | Extra arguments to pass to the mmdc command.                                                   |
| `ascii_args`           | `{ "-C", "-c" }`                         | Extra arguments to pass to ascii-image-converter.                                              |
| `output_ext`           | `".png"`                                 | File extension for the generated Mermaid output (usually `.png`).                              |
| `debug`                | `false`                                  | If `true`, we print debug logs.                                                                |



---



## Dependencies

1. [Mermaid CLI](https://github.com/mermaid-js/mermaid-cli)
   - **Install via NPM**:
     ```bash
     npm install -g @mermaid-js/mermaid-cli
     ```
   - Ensures the `mmdc` command is available in your `$PATH`.

2. [ascii-image-converter](https://github.com/TheZoraiz/ascii-image-converter) (if using `renderer = "ascii"`)
   - You might install it via `cargo` or from your distribution’s package manager, e.g.:
     ```bash
     cargo install ascii-image-converter
     ```
   - This will give you the `ascii-image-converter` command in `$PATH`.

3. [image.nvim](https://github.com/your-image-nvim-repo) (if using `renderer = "image"`)
   - Make sure it’s installed and available in your Neovim runtime.


# Advanced Topics :
### Multiple Patterns

If your code sometimes has diagrams in # diagram: lines, just add that pattern:
```lua
comment_patterns = {
  "%s*//+%s*diagram:%s*(.*)",
  "%s*#%s*diagram:%s*(.*)",
}
```
# Caching Details
Struml stores the rendered diagram in a small in-memory Lua table keyed by a hash of the diagram text. If you edit the diagram text in your code, Struml sees that it’s changed and re-renders. Otherwise, it reuses the same ASCII/PNG output.

# Error Handling 
If something goes wrong (like Mermaid or ascii-image-converter fails), Struml will pop up an error in Neovim. The floating window won't appear, but you’ll know why it failed so you can fix the issue quickly.

# Optional image.nvim Integration
If you set renderer = "image", Struml calls [image.nvim](https://github.com/your-image-nvim-repo) to show the actual PNG in a floating window. Make sure you have that plugin installed & configured. If you don’t, we’ll show an error message telling you to either install it or switch back to ASCII mode.



---



# License
Struml is distributed under the MIT License, which means you are free to clone, modify, redistribute, or build upon this project. See LICENSE for the full text.
```vbnet 
MIT License

Copyright (c) 2025 migbyte-0

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:
```


---



# Happy diagramming!
Feel free to open PRs, issues, or share your feedback. Let’s keep our code flows clear and our ASCII art fancy.
Struml on!
