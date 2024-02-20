-- wezterm.lua

local wezterm = require 'wezterm'

local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- My config preferences

config.default_cwd = wezterm.home_dir  -- doesn't do what you'd like to think
config.font = wezterm.font 'JetBrainsMonoNL Nerd Font Mono'
-- config.color_scheme = 'Solarized (dark) (terminal.sexy)'
-- config.color_scheme = 'Solarized Dark (Gogh)'
-- config.color_scheme = 'Solarized Dark Higher Contrast'
config.color_scheme = 'Solarized Dark Higher Contrast (Gogh)'

config.window_frame = {
  -- The font used in the tab bar.  Roboto Bold is the default; bundled with wezterm.
  -- Whatever font is selected here, it will have the main font setting appended to it to pick
  -- up any fallback fonts you may have used there.
  font = wezterm.font { family = 'Roboto', weight = 'Regular' },

  font_size = 10.0,

  -- The tab bar when the window is focused
  active_titlebar_bg = '#668066',

  -- The tab bar when the window is not focused
  -- Seems to only be 'focused' on click
  inactive_titlebar_bg = '#668066',
}

config.colors = {
  tab_bar = {
    -- The color of the inactive tab bar edge/divider
    inactive_tab_edge = '#578057',
  },
}

-- return the configuration to wezterm
return config
