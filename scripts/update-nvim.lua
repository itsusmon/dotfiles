local component = vim.env.UPDATE_NVIM_COMPONENT
local checking = vim.env.UPDATE_MODE == 'check'
local function print(message)
  io.stdout:write(message .. '\n')
  io.stdout:flush()
end

local ok, err = xpcall(function()
  if vim.v.errmsg ~= '' then error(vim.v.errmsg) end
  if checking and component == 'lazy' then
    local lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json'
    if vim.fn.filereadable(lockfile) == 0 then print('[SKIP] No lazy.nvim lockfile.'); return end
    local plugins = vim.json.decode(table.concat(vim.fn.readfile(lockfile), '\n'))
    local failed = false
    for name, pin in pairs(plugins) do
      local dir = vim.fn.stdpath('data') .. '/lazy/' .. name
      if vim.fn.isdirectory(dir .. '/.git') == 1 and pin.branch then
        local remote = vim.fn.system({ 'git', '-C', dir, 'ls-remote', '--exit-code', 'origin', 'refs/heads/' .. pin.branch })
        if vim.v.shell_error ~= 0 then print('[FAILED] ' .. name .. ': ' .. remote); failed = true
        elseif remote:match('^(%x+)') ~= pin.commit then
          print(name .. ': newer/different branch head available (configured pins still apply).')
        else print(name .. ': up to date with ' .. pin.branch) end
      end
    end
    assert(not failed, 'Some plugin checks failed.')
    return
  elseif checking then
    -- Use -u NONE in check mode: a user's init can bootstrap missing plugins.
    local mason = vim.fn.stdpath('data') .. '/lazy/mason.nvim'
    if vim.fn.isdirectory(mason) == 0 then
      print('[SKIP] No lazy.nvim-managed Mason installation.')
      return
    end
    vim.opt.rtp:append(mason)
    require('mason').setup()
  elseif package.loaded.lazy then
    if component ~= 'lazy' then require('lazy').load({ plugins = { 'mason.nvim', 'nvim-treesitter' } }) end
  end

  if component == 'lazy' then
    if not package.loaded.lazy then print('[SKIP] lazy.nvim is not configured.'); return end
    require('lazy').update({ wait = true, show = false })
    local failed = false
    for name, plugin in pairs(require('lazy.core.config').plugins) do
      for _, task in ipairs(plugin._.tasks or {}) do
        if task:has_errors() then
          print('[FAILED] ' .. name .. ': ' .. task:output())
          failed = true
        end
      end
    end
    assert(not failed, 'One or more plugin updates failed.')
  elseif component == 'mason' then
    local found, registry = pcall(require, 'mason-registry')
    if not found then print('[SKIP] Mason is not configured.'); return end
    local done, success = false, false
    registry.update(function(result) success = result; done = true end)
    assert(vim.wait(120000, function() return done end, 50), 'Mason registry check timed out.')
    assert(success, 'Mason registry refresh failed.')
    local packages = {}
    for _, pkg in ipairs(registry.get_installed_packages()) do
      local current, latest = pkg:get_installed_version(), pkg:get_latest_version()
      if current ~= latest then
        print(pkg.name .. ': ' .. tostring(current) .. ' -> ' .. latest)
        packages[#packages + 1] = pkg.name
      end
    end
    if #packages == 0 then print('Mason tools are up to date.')
    elseif not checking then
      -- Quiet avoids treating harmless installer stderr (e.g. tar) as a Vim error.
      -- Mason still waits for every install and exits nonzero on real failures.
      vim.cmd('MasonInstall --quiet ' .. table.concat(packages, ' '))
    end
  elseif component == 'treesitter' then
    local found, treesitter = pcall(require, 'nvim-treesitter')
    if not found then print('[SKIP] nvim-treesitter is not configured.'); return end
    if treesitter.update then
      assert(treesitter.update(nil, { summary = true }):wait(300000), 'Parser update failed.')
    elseif vim.fn.exists(':TSUpdateSync') == 2 then
      vim.cmd('TSUpdateSync')
    else error('Unsupported Tree-sitter API; update parsers manually.') end
  else error('Unknown component: ' .. tostring(component)) end
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
else vim.cmd('qa!') end
