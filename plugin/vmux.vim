function! VmuxRunnerOpen(name)
  if g:Vmux.Runners[a:name].state.state ==# "off"
    echom "opening runner"
"    if !VmuxOption("g:VmuxEnableHijack",0) || !VmuxRunnerHijack(g:Vmux.Runners[a:name].state.mode)
"      call VmuxRunnerCreate() 
"    endif
    if VmuxOption("g:VmuxEnableHijack",1)
      if !VmuxRunnerHijack(g:Vmux.Runners[a:name].state.mode)
	call VmuxRunnerCreate(g:Vmux.Runners[a:name].state.mode)
      endif
    else
      call VmuxRunnerCreate(g:Vmux.Runners[a:name].state.mode)
    endif
  elseif !VmuxRunnerPaneExists(a:name)
    call VmuxRunnerReset()
    call VmuxRunnerOpen()
  else
    echo "Runner is already open!"
  endif
endfunction

function! VmuxRunCommand(name, command)
  if !VmuxRunnerPaneExists(a:name) || g:Vmux.Runners[a:name].state.state ==# "off"
    call VmuxRunnerOpen()
  endif

  call VmuxSendKeys(VmuxOption("g:VmuxResetSequence", "q C-u"))
  call VmuxSendKeys("\"".escape(a:command, "\"\\$`")."\"")
  call VmuxSendKeys("Enter")
endfunction

function! VmuxRunnerHijack(mode)
  let pane = VmuxFindHostPane(a:mode)
  if pane != ""
    let g:Vmux.Runners[a:name].state.state = "on"
    let g:Vmux.Runners[a:name].state.id = pane
    return 1
  endif
  return 0
endfunction

" finds the first suitable host pane
function! VmuxFindHostPane(mode)
  let mode = a:mode
  let vim_pane = split(VmuxTmuxProperty("#I.#P,#{pane_active}"),"\,")
  if mode ==# "pane"
    let panes = split(VmuxTmux("list-panes -F \"#I.#P,#{pane_active}\""),"\n")
    let i = 0
    while i < len(panes)
      let pane = split(panes[i], "\,")
      if pane[1] == 0 && pane[0][0] == vim_pane[0][0] && VmuxPaneValidShell(pane[0])
	return VmuxTmuxProperty("#D",pane[0])
      endif
      let i += 1
    endwhile
  elseif mode ==# "window"
    let panes = split(VmuxTmux("list-panes -s -F \"#I.#P,#{pane_active}\""),"\n")
    let i = 0
    while i < len(panes)
      let pane = split(panes[i], "\,")
      if pane[1] == 1 && pane[0][0] != vim_pane[0][0] 
	    \&& len(split(VmuxTmux("list-panes -t ".vim_pane[0][0]." -F \"#I.#P\"","\n"))) == 1 
	    \&& VmuxPaneValidShell(pane[0])
	return VmuxTmuxProperty("#D",pane[0])
      endif
      let i += 1
    endwhile
  endif
  return "" 
endfunction

" argument is any valid string for tmux -t option
function! VmuxPaneValidShell(pane)
  let tty = substitute(substitute(VmuxTmux("display -t ".a:pane." -p \"#{pane_tty}\""),"\n","",""),"/dev/","","")
  let procs = split(system("pgrep -l -t".tty),"\n")
  if len(procs) != 1
    return 0
  else
    for shell in VmuxOption("g:VmuxShells",["bash","zsh"])
      if match(procs[0], shell) != -1
	return 1
      endif
    endfor
    return 0
  endif
endfunction

function! VmuxRunnerReset(name)
  if !exists("g:Vmux.Runners[a:name]")
    echoerr "error: VmuxRunnerReset"
    return -1
  else
    let g:Vmux.Runners[a:name].state.state = g:Vmux.initrunnerstate.state
    let g:Vmux.Runners[a:name].state.id = g:Vmux.initrunnerstate.id
    return 0
  endif
endfunction

function! VmuxRunnerPaneExists(name)
  if !exists("g:Vmux.Runners[a:name]")
    echoerr "error: VmuxRunnerPaneExists"
    return -1
  else
    call VmuxTmux("has-session -t".g:Vmux.Runners[a:name].state.id)
    return !v:shell_error
  endif
endfunction

function! VmuxRunnerToggleMode(name)
  if !exists("g:Vmux.Runners[a:name]")
    echoerr "error: VmuxRunnerToggleMode"
    return -1
  else
    let r = g:Vmux.Runners[a:name]
    if r.state.state ==# "on" && VmuxRunnerPaneExists(a:name)

      let tmuxcmd = r.state.mode ==# 'pane' ? 'break-pane' : 'join-pane'
      let focus = r.options.focus == 1 ? "" : " -d"
      let source = " -s ". r.state.id

      if r.state.mode ==# "window"
	let vertical = r.options.vertical == 1 ? " -v" : " -h"
	let percent = " -p " .r.options.percent
	call VmuxTmux(tmuxcmd . focus . vertical . percent. source)
      elseif r.state.mode ==# "pane"
	call VmuxTmux(tmuxcmd . focus . source)
      endif

    elseif r.state.state ==# "on"
      call VmuxRunnerReset(a:name)
    endif
    let r.state.mode = r.state.mode ==# "pane" ? "window" : "pane"
    echo VmuxRunnerStatus(a:name)
  endif
endfunction

function! VmuxRunnerGetIndex(name)
  return VmuxTmuxProperty("#I.#P", g:Vmux.Runners[a:name].state.id)
endfunction

function! VmuxSendKeys(keys)
  if g:Vmux.Runners[a:name].state.state ==# "on" && VmuxRunnerPaneExists(a:name)
    call VmuxTmux("send-keys -t ".g:Vmux.Runners[a:name].state.id." ".a:keys)
  else
    echo "No Runner or Invalid Runner ID!"
    call VmuxRunnerReset()
  endif
endfunction

function! VmuxRunnerStatus(name)
  if !exists("g:Vmux.Runners[a:name]")
    echoerr "error: VmuxRunnerStatus"
    return -1
  else
    "return g:Vmux.Runners[a:name]
    exe "return \"Runner Type: \".g:Vmux.Runners[a:name].state.mode.\"	|	\".(VmuxRunnerPaneExists(a:name)?\"Runner Index: \".g:VmuxRunnerGetIndex(a:name):\"Runner Disabled\")"
  endif
endfunction

function! VmuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

" First optional argument is any valid string for tmux -t option
function! VmuxTmuxProperty(property, ...)
  let target = exists("a:1") ? "-t ".a:1." " : ""
  return substitute(VmuxTmux("display-message -p ".target."'".a:property."'"), '\n$', '', '')
endfunction

function! VmuxTmux(arguments)
  let l:command = VmuxOption("g:VmuxTmuxCommand", "tmux")
  return system(l:command." ".a:arguments)
endfunction

"" Vmux state
let g:Vmux = {}
let g:Vmux.defaultrunneroptions = {'vertical' : 1, 'percent' : 20, 'startdir' : '', 'command' : '', 'focus' : 0}
let g:Vmux.opts2 = {'vertical' : 0, 'percent' : 50, 'startdir' : '', 'command' : 'zsh', 'focus' : 0}
let g:Vmux.initrunnerstate = {'mode' : 'pane', 'id' : '', 'state' : 'off'}
let g:Vmux.Runners = {'' : {'options' : copy(g:Vmux.defaultrunneroptions), 'state' : copy(g:Vmux.initrunnerstate)}}

function! g:Vmux.AddRunner(name, runneroptions)
  if exists("g:Vmux.Runners['a:name']")
    return -1
  else
    let g:Vmux.Runners[a:name] = {'options' : a:runneroptions, 'state' : copy(g:Vmux.initrunnerstate)}
    return
  endif
endfunction

function! VmuxRunnerEnable(name)
  if !exists("g:Vmux.Runners[a:name]")
    echoerr "error: VmuxRunnerEnable"
    return -1
  else
    let g:Vmux.Runners[a:name].state.state = "on"
    let command = VmuxRunnerCommand(a:name)
    if g:Vmux.Runners[a:name].state.mode ==# "pane"
      call VmuxTmux(command)
      let g:Vmux.Runners[a:name].state.id = VmuxTmuxProperty("#D")
      if g:Vmux.Runners[a:name].options.focus == 0
	call VmuxTmux("select-pane -t !")
      endif
    elseif g:Vmux.Runners[a:name].state.mode ==# "window"
      call VmuxTmux(command)
      let g:Vmux.Runners[a:name].state.id = VmuxTmuxProperty("#D")
      if g:Vmux.Runners[a:name].options.focus == 0
	call VmuxTmux("select-window -t !")
      endif
    endif
    return
  endif
endfunction

function! VmuxRunnerDisable(name)
  if !exists("g:Vmux.Runners[a:name]")
    echoerr "error: VmuxRunnerDisable"
    return -1
  else
    if g:Vmux.Runners[a:name].state.state ==# "on" && VmuxRunnerPaneExists(a:name)
      if VmuxTmuxProperty("#D") ==# g:Vmux.Runners[a:name].state.id
	echoerr "error: VmuxRunnerDisable"
	return -1
      endif
      call VmuxTmux("kill-pane"." -t ".g:Vmux.Runners[a:name].state.id)
      let g:Vmux.Runners[a:name].state.state = "off"
      let g:Vmux.Runners[a:name].state.id = ""
    else
      echo "No Runner or Invalid Runner ID!"
      call VmuxRunnerReset(a:name)
    endif
  endif
endfunction

function! VmuxRunnerCommand(name)
  if !exists("g:Vmux.Runners[a:name]")
    return -1
  else
    let r = g:Vmux.Runners[a:name]
    let tmuxcmd = r.state.mode ==# 'pane' ? 'split-window' : 'new-window'
    let focus = ""
    let dir = r.options.startdir ==# "" ? "" : " -c ".r.options.startdir
    let command = " ".r.options.command
    if r.state.mode ==# 'pane'
      let vertical = r.options.vertical == 1 ? " -v" : " -h"
      let percent = " -p " .r.options.percent
      return tmuxcmd . focus . dir . vertical . percent . command
    else
      return tmuxcmd . focus . dir . command
    endif
  endif
endfunction

"let s:RunnerType = {}
"function! s:RunnerType.New(runnertype)
"  let newRunnerType = copy(self)
"  let newRunnerType.vertical = VmuxOption("a:runnertype.vertical", 1)
"  let newRunnerType.percent = VmuxOption("a:runnertype.percent", 20)
"  let newRunnerType.startdir = VmuxOption("a:runnertype.startdir", "")
"  let newRunnerType.command = VmuxOption("a:runnertype.command", "")
"  let newRunnerType.focus = VmuxOption("a:runnertype.focus", 0)
"  return newRunnerType
"endfunction
