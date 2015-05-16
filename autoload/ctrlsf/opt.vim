" option list of CtrlSF
let s:option_list = {
    \ '-after'      : {'args': 1},
    \ '-before'     : {'args': 1},
    \ '-context'    : {'args': 1},
    \ '-ignorecase' : {'args': 0},
    \ '-regex'      : {'args': 0},
    \ '-filetype'   : {'args': 1},
    \ '-A': {'fullname': '-after'},
    \ '-B': {'fullname': '-before'},
    \ '-C': {'fullname': '-context'},
    \ '-I': {'fullname': '-ignorecase'},
    \ '-R': {'fullname': '-regexp'},
    \ }

" default values to options
let s:default = {
    \ 'after'      : -1,
    \ 'before'     : -1,
    \ 'context'    : -1,
    \ 'ignorecase' : g:ctrlsf_ignore_case,
    \ 'regex'      : 0,
    \ 'filetype'   : 0,
    \ 'pattern'    : '',
    \ 'path'       : [],
    \ }

" options
let s:options = {}

" HasOpt()
"
" Return whether user has given a specific option
"
func! ctrlsf#opt#HasOpt(name) abort
    return has_key(s:options, a:name)
endf

" GetOpt()
"
" Return option {name}, if not exists, return default value
"
func! ctrlsf#opt#GetOpt(name) abort
    return get(s:options, a:name, s:default[a:name])
endf

" NextToken()
"
" Return nex token of {chars}, which starts from {start}.
"
func! s:NextToken(chars, start) abort
    let buffer      = []
    let state_stack = ['normal']
    let start       = a:start

    while start < len(a:chars)
        let state = state_stack[-1]
        let char  = a:chars[start]
        let start += 1

        " char: [space]
        if char ==# ' '
            if state == 'normal'
                " ignore leading space
                if !empty(buffer)
                    break
                endif
            elseif state == 'escape'
                call add(buffer, char)
                call remove(state_stack, -1)
            else
                call add(buffer, char)
            endif
        " char: "
        elseif char ==# '"'
            if state == 'normal'
                call add(state_stack, 'string_double')
            elseif state == 'string_double'
                call remove(state_stack, -1)
                break
            elseif state == 'escape'
                call remove(state_stack, -1)
            else
                call add(buffer, char)
            endif
        " char: '
        elseif char ==# "'"
            if state == 'normal'
                call add(state_stack, 'string_single')
            elseif state == 'string_single'
                call remove(state_stack, -1)
                break
            else
                call add(buffer, char)
            endif
        " char: \
        elseif char ==# '\'
            if state == 'normal' || state == 'string_double'
                call add(state_stack, 'escape')
            elseif state == 'string_single'
                call add(buffer, char)
            elseif state == 'escape'
                call add(buffer, char)
                call remove(state_stack, -1)
            endif
        " normal characters
        else
            call add(buffer, char)
        endif
    endwh

    if len(state_stack) != 1 || state_stack[-1] != 'normal'
        call ctrlsf#log#Error("Unable to parse options: %s.", join(chars, ''))
        throw "ParseOptionsException"
    endif

    return [join(buffer, ''), start]
endf

" Tokenize()
"
" Split string into a list of tokens.
"
" Examples
" -I -C 2 path     -> ['-I', '-C', '2', 'path']
" -regex 'foo bar' -> ['-regex', 'foo bar']
" foo\ bar         -> ['foo bar']
"
func! s:Tokenize(options_str) abort
    let tokens = []
    let chars  = split(a:options_str, '.\zs')

    let start = 0
    while 1
        let [token, start] = s:NextToken(chars, start)
        if empty(token)
            break
        else
            call add(tokens, token)
        endif
    endwh

    return tokens
endf

" ParseOptions()
"
" Create a dict contains parsed options
"
func! s:ParseOptions(options_str) abort
    let options = {}
    let tokens = s:Tokenize(a:options_str)

    let i = 0
    while i < len(tokens)
        let token = tokens[i]
        let i += 1

        if !has_key(s:option_list, token)
            if token =~# '^-'
                call ctrlsf#log#Error("Unknown option '%s'. If you are user
                    \ from pre-v1.0, plaese be aware of CtrlSF v1.0 no longer
                    \ supports all options of ack and ag. Read manual for
                    \ CtrlSF its own options.", token)
                throw 'ParseOptionsException'
            endif

            " resolve to PATTERN and PATH
            if !has_key(options, 'pattern')
                let options['pattern'] = token
            else
                if !has_key(options, 'path')
                    let options['path'] = []
                endif
                call add(options['path'], token)
            endif

            continue
        endif

        let name = strpart(token, 1)
        let opt  = s:option_list[token]
        if has_key(opt, 'fullname')
            let name = strpart(opt.fullname, 1)
            let opt  = s:option_list[opt.fullname]
        endif

        if opt.args == 0
            let options[name] = 1
        elseif opt.args == 1
            if tokens[i] =~# '\d\+'
                let options[name] = str2nr(tokens[i])
            else
                let options[name] = tokens[i]
            endif

            let i += 1
        else
            let argv = []
            for j in range(opt.args)
                call add(argv, tokens[i])
                let i += 1
            endfo

            let options[name] = argv
        endif
    endwh

    return options
endf

" ctrlsf#opt#ParseOptions()
"
func! ctrlsf#opt#ParseOptions(options_str) abort
    let s:options = s:ParseOptions(a:options_str)
endf

""
" Initialization
"

" read from configuration
let ctx_opt = s:ParseOptions(g:ctrlsf_context)
let s:default.after   = get(ctx_opt, 'after', -1)
let s:default.before  = get(ctx_opt, 'before', -1)
let s:default.context = get(ctx_opt, 'context', -1)
