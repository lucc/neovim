-- Test for various eval features.
-- Note: system clipboard support is not tested. I do not think anybody will
-- thank me for messing with clipboard.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval, wait, write_file = helpers.eq, helpers.eval, helpers.wait, helpers.write_file

describe('various eval features', function()
  setup(function()
    write_file('test_eval_setup.vim', [[
      set encoding=latin1
      set noswapfile
      lang C

      fun RegInfo(reg)
        return [
	  \ a:reg,
	  \ getregtype(a:reg),
	  \ getreg(a:reg),
	  \ string(getreg(a:reg, 0, 1)),
	  \ getreg(a:reg, 1),
	  \ string(getreg(a:reg, 1, 1))
	  \ ]
      endfun

      fun AppendRegContents(reg)
      let x = RegInfo(a:reg)
	call append('$', printf('%s: type %s; value: %s (%s), expr: %s (%s)',
	  \ x[0], x[1], x[2], x[3], x[4], x[5]))
      endfun

      command -nargs=? AR :call AppendRegContents(<q-args>)

      fun SetReg(...)
          call call('setreg', a:000)
          call append('$', printf('{{{2 setreg(%s)', string(a:000)[1:-2]))
          call AppendRegContents(a:1)
          if a:1 isnot# '='
              execute "silent normal! Go==\n==\e\"".a:1."P"
          endif
      endfun

      fun ErrExe(str)
	call append('$', 'Executing '.a:str)
	try
	  execute a:str
	catch
	  $put =v:exception
	endtry
      endfun
      ]])
    write_file('test_eval_func.vim', [[
      " Vim script used in test_eval.in.  Needed for script-local function.
      
      func! s:Testje()
        return "foo"
      endfunc
      
      let Bar = function('s:Testje')
      
      $put ='s:Testje exists: ' . exists('s:Testje')
      $put ='func s:Testje exists: ' . exists('*s:Testje')
      $put ='Bar exists: ' . exists('Bar')
      $put ='func Bar exists: ' . exists('*Bar')
      ]])
  end)
  before_each(clear)
  teardown(function()
    os.remove('test.out')
    os.remove('test_eval_func.vim')
    os.remove('test_eval_setup.vim')
  end)

  it('let tests', function()
    execute('so test_eval_setup.vim')
    execute([[let @" = 'abc']])
    execute('AR "')
    execute([[let @" = "abc\n"]])
    source('AR "')
    execute([[let @" = "abc\<C-m>"]])
    execute('AR "')
    execute([[let @= = '"abc"']])
    execute('AR =')
    expect([[
      
      ": type v; value: abc (['abc']), expr: abc (['abc'])
      ": type V; value: abc]].."\x00 (['abc']), expr: abc\x00"..[[ (['abc'])
      ": type V; value: abc]].."\r\x00 (['abc\r']), expr: abc\r\x00 (['abc\r"..[['])
      =: type v; value: abc (['abc']), expr: "abc" (['"abc"'])]])
  end)

  it('Basic setreg tests', function()
    execute('so test_eval_setup.vim')
    execute([[call SetReg('a', 'abcA', 'c')]])
    execute([[call SetReg('b', 'abcB', 'v')]])
    execute([[call SetReg('c', 'abcC', 'l')]])
    execute([[call SetReg('d', 'abcD', 'V')]])
    execute([[call SetReg('e', 'abcE', 'b')]])
    execute([[call SetReg('f', 'abcF', "\<C-v>")]])
    execute([[call SetReg('g', 'abcG', 'b10')]])
    execute([[call SetReg('h', 'abcH', "\<C-v>10")]])
    execute([[call SetReg('I', 'abcI')]])
    expect([[
      
      {{{2 setreg('a', 'abcA', 'c')
      a: type v; value: abcA (['abcA']), expr: abcA (['abcA'])
      ==
      =abcA=
      {{{2 setreg('b', 'abcB', 'v')
      b: type v; value: abcB (['abcB']), expr: abcB (['abcB'])
      ==
      =abcB=
      {{{2 setreg('c', 'abcC', 'l')
      c: type V; value: abcC]].."\x00 (['abcC']), expr: abcC\x00"..[[ (['abcC'])
      ==
      abcC
      ==
      {{{2 setreg('d', 'abcD', 'V')
      d: type V; value: abcD]].."\x00 (['abcD']), expr: abcD\x00"..[[ (['abcD'])
      ==
      abcD
      ==
      {{{2 setreg('e', 'abcE', 'b')
      e: type ]]..'\x16'..[[4; value: abcE (['abcE']), expr: abcE (['abcE'])
      ==
      =abcE=
      {{{2 setreg('f', 'abcF', ']]..'\x16'..[[')
      f: type ]]..'\x16'..[[4; value: abcF (['abcF']), expr: abcF (['abcF'])
      ==
      =abcF=
      {{{2 setreg('g', 'abcG', 'b10')
      g: type ]]..'\x16'..[[10; value: abcG (['abcG']), expr: abcG (['abcG'])
      ==
      =abcG      =
      {{{2 setreg('h', 'abcH', ']]..'\x16'..[[10')
      h: type ]]..'\x16'..[[10; value: abcH (['abcH']), expr: abcH (['abcH'])
      ==
      =abcH      =
      {{{2 setreg('I', 'abcI')
      I: type v; value: abcI (['abcI']), expr: abcI (['abcI'])
      ==
      =abcI=]])
  end)

  it('are working', function()
    insert([[
      012345678
      012345678
      
      start:]])

    source([[
    so test_eval_setup.vim
    ]])
    --execute('fun Test()')
    expect([[
    012345678
    012345678
    
    start:]])

    execute([[$put ='{{{1 Appending single lines with setreg()']])
    execute([[call SetReg('A', 'abcAc', 'c')]])
    execute([[call SetReg('A', 'abcAl', 'l')]])
    execute([[call SetReg('A', 'abcAc2','c')]])
    execute([[call SetReg('b', 'abcBc', 'ca')]])
    execute([[call SetReg('b', 'abcBb', 'ba')]])
    execute([[call SetReg('b', 'abcBc2','ca')]])
    execute([[call SetReg('b', 'abcBb2','b50a')]])
    execute([[call SetReg('C', 'abcCl', 'l')]])
    execute([[call SetReg('C', 'abcCc', 'c')]])
    execute([[call SetReg('D', 'abcDb', 'b')]])
    execute([[call SetReg('E', 'abcEb', 'b')]])
    execute([[call SetReg('E', 'abcEl', 'l')]])
    execute([[call SetReg('F', 'abcFc', 'c')]])

    execute([[$put ='{{{1 Appending NL with setreg()']])
    execute([[call setreg('a', 'abcA2', 'c')]])
    execute([[call setreg('b', 'abcB2', 'v')]])
    execute([[call setreg('c', 'abcC2', 'l')]])
    execute([[call setreg('d', 'abcD2', 'V')]])
    execute([[call setreg('e', 'abcE2', 'b')]])
    execute([[call setreg('f', 'abcF2', "\<C-v>")]])
    execute([[call setreg('g', 'abcG2', 'b10')]])
    execute([[call setreg('h', 'abcH2', "\<C-v>10")]])
    execute([[call setreg('I', 'abcI2')]])
    execute([[call SetReg('A', "\n")]])
    execute([[call SetReg('B', "\n", 'c')]])
    execute([[call SetReg('C', "\n")]])
    execute([[call SetReg('D', "\n", 'l')]])
    execute([[call SetReg('E', "\n")]])
    execute([[call SetReg('F', "\n", 'b')]])

    execute([[$put ='{{{1 Setting lists with setreg()']])
    execute([=[call SetReg('a', ['abcA3'], 'c')]=])
    execute([=[call SetReg('b', ['abcB3'], 'l')]=])
    execute([=[call SetReg('c', ['abcC3'], 'b')]=])
    execute([=[call SetReg('d', ['abcD3'])]=])
    execute([=[call SetReg('e', [1, 2, 'abc', 3])]=])
    execute([=[call SetReg('f', [1, 2, 3])]=])

    execute([[$put ='{{{1 Appending lists with setreg()']])
    execute([=[call SetReg('A', ['abcA3c'], 'c')]=])
    execute([=[call SetReg('b', ['abcB3l'], 'la')]=])
    execute([=[call SetReg('C', ['abcC3b'], 'lb')]=])
    execute([=[call SetReg('D', ['abcD32'])]=])
    execute([=[call SetReg('A', ['abcA32'])]=])
    execute([=[call SetReg('B', ['abcB3c'], 'c')]=])
    execute([=[call SetReg('C', ['abcC3l'], 'l')]=])
    execute([=[call SetReg('D', ['abcD3b'], 'b')]=])

    execute([[$put ='{{{1 Appending lists with NL with setreg()']])
    execute([=[call SetReg('A', ["\n", 'abcA3l2'], 'l')]=])
    execute([=[call SetReg('B', ["\n", 'abcB3c2'], 'c')]=])
    execute([=[call SetReg('C', ["\n", 'abcC3b2'], 'b')]=])
    execute([=[call SetReg('D', ["\n", 'abcD3b50'],'b50')]=])

    execute([[$put ='{{{1 Setting lists with NLs with setreg()']])
    execute([=[call SetReg('a', ['abcA4-0', "\n", "abcA4-2\n", "\nabcA4-3", "abcA4-4\nabcA4-4-2"])]=])
    execute([=[call SetReg('b', ['abcB4c-0', "\n", "abcB4c-2\n", "\nabcB4c-3", "abcB4c-4\nabcB4c-4-2"], 'c')]=])
    execute([=[call SetReg('c', ['abcC4l-0', "\n", "abcC4l-2\n", "\nabcC4l-3", "abcC4l-4\nabcC4l-4-2"], 'l')]=])
    execute([=[call SetReg('d', ['abcD4b-0', "\n", "abcD4b-2\n", "\nabcD4b-3", "abcD4b-4\nabcD4b-4-2"], 'b')]=])
    execute([=[call SetReg('e', ['abcE4b10-0', "\n", "abcE4b10-2\n", "\nabcE4b10-3", "abcE4b10-4\nabcE4b10-4-2"], 'b10')]=])

    execute([[$put ='{{{1 Search and expressions']])
    execute([=[call SetReg('/', ['abc/'])]=])
    execute([=[call SetReg('/', ["abc/\n"])]=])
    execute([=[call SetReg('=', ['"abc/"'])]=])
    execute([=[call SetReg('=', ["\"abc/\n\""])]=])

    execute([[$put ='{{{1 Errors']])
    execute([[call ErrExe('call setreg()')]])
    execute([[call ErrExe('call setreg(1)')]])
    execute([[call ErrExe('call setreg(1, 2, 3, 4)')]])
    execute([=[call ErrExe('call setreg([], 2)')]=])
    execute([[call ErrExe('call setreg(1, {})')]])
    execute([=[call ErrExe('call setreg(1, 2, [])')]=])
    execute([=[call ErrExe('call setreg("/", ["1", "2"])')]=])
    execute([=[call ErrExe('call setreg("=", ["1", "2"])')]=])
    execute([=[call ErrExe('call setreg(1, ["", "", [], ""])')]=])
    --execute('endfun')

    execute('delfunction SetReg')
    execute('delfunction AppendRegContents')
    execute('delfunction ErrExe')
    execute('delcommand AR')
    execute('call garbagecollect(1)')

    execute('/^start:/+1,$w! test.out')
    -- Vim: et ts=4 isk-=\: fmr=???,???. -- TODO
    --execute('call getchar()') -- TODO
    execute('e! test.out')
    execute('%d')
    -- Function name not starting with a capital.
    execute('try')
    execute('  func! g:test()')
    execute('    echo "test"')
    execute('  endfunc')
    execute('catch')
    execute('  $put =v:exception')
    execute('  let tmp = v:exception')
    execute('endtry')
    eq('Vim(function):E128: Function name must start with a capital or "s:": g:test()', eval('tmp'))
    -- Function name folowed by #.
    execute('try')
    execute('  func! test2() "#')
    execute('    echo "test2"')
    execute('  endfunc')
    execute('catch')
    execute('  $put =v:exception')
    execute('endtry')
    -- Function name includes a colon.
    execute('try')
    execute('  func! b:test()')
    execute('    echo "test"')
    execute('  endfunc')
    execute('catch')
    execute('  $put =v:exception')
    execute('endtry')
    -- Function name starting with/without "g:", buffer-local funcref.
    execute('function! g:Foo(n)')
    execute("  $put ='called Foo(' . a:n . ')'")
    execute('endfunction')
    execute("let b:my_func = function('Foo')")
    execute('call b:my_func(1)')
    execute('echo g:Foo(2)')
    execute('echo Foo(3)')
    -- Script-local function used in Funcref must exist.
    execute('so test_eval_func.vim')
    -- Using $ instead of '$' must give an error.
    execute('try')
    execute("  call append($, 'foobar')")
    execute('catch')
    execute('  $put =v:exception')
    execute('endtry')
    execute("$put ='{{{1 getcurpos/setpos'")
    execute('/^012345678')
    feed('6l')
    execute('let sp = getcurpos()')
    feed('0')
    execute("call setpos('.', sp)")
    feed('jyl')
    execute('$put')
    execute('0,/^start:/ delete')
    -- Vim: et ts=4 isk-=\: fmr=???,???. TODO does this affect the test?
    --execute('call getchar()')

    -- Assert buffer contents.
    expect([[
      {{{1 Appending single lines with setreg()
      {{{2 setreg('A', 'abcAc', 'c')
      A: type v; value: abcAabcAc (['abcAabcAc']), expr: abcAabcAc (['abcAabcAc'])
      ==
      =abcAabcAc=
      {{{2 setreg('A', 'abcAl', 'l')
      A: type V; value: abcAabcAcabcAl]].."\x00 (['abcAabcAcabcAl']), expr: abcAabcAcabcAl\x00"..[[ (['abcAabcAcabcAl'])
      ==
      abcAabcAcabcAl
      ==
      {{{2 setreg('A', 'abcAc2', 'c')
      A: type v; value: abcAabcAcabcAl]].."\x00abcAc2 (['abcAabcAcabcAl', 'abcAc2']), expr: abcAabcAcabcAl\x00"..[[abcAc2 (['abcAabcAcabcAl', 'abcAc2'])
      ==
      =abcAabcAcabcAl
      abcAc2=
      {{{2 setreg('b', 'abcBc', 'ca')
      b: type v; value: abcBabcBc (['abcBabcBc']), expr: abcBabcBc (['abcBabcBc'])
      ==
      =abcBabcBc=
      {{{2 setreg('b', 'abcBb', 'ba')
      b: type ]]..'\x16'..[[5; value: abcBabcBcabcBb (['abcBabcBcabcBb']), expr: abcBabcBcabcBb (['abcBabcBcabcBb'])
      ==
      =abcBabcBcabcBb=
      {{{2 setreg('b', 'abcBc2', 'ca')
      b: type v; value: abcBabcBcabcBb]].."\x00abcBc2 (['abcBabcBcabcBb', 'abcBc2']), expr: abcBabcBcabcBb\x00"..[[abcBc2 (['abcBabcBcabcBb', 'abcBc2'])
      ==
      =abcBabcBcabcBb
      abcBc2=
      {{{2 setreg('b', 'abcBb2', 'b50a')
      b: type ]].."\x1650; value: abcBabcBcabcBb\x00abcBc2abcBb2 (['abcBabcBcabcBb', 'abcBc2abcBb2']), expr: abcBabcBcabcBb\x00"..[[abcBc2abcBb2 (['abcBabcBcabcBb', 'abcBc2abcBb2'])
      ==
      =abcBabcBcabcBb                                    =
       abcBc2abcBb2
      {{{2 setreg('C', 'abcCl', 'l')
      C: type V; value: abcC]].."\x00abcCl\x00 (['abcC', 'abcCl']), expr: abcC\x00abcCl\x00"..[[ (['abcC', 'abcCl'])
      ==
      abcC
      abcCl
      ==
      {{{2 setreg('C', 'abcCc', 'c')
      C: type v; value: abcC]].."\x00abcCl\x00abcCc (['abcC', 'abcCl', 'abcCc']), expr: abcC\x00abcCl\x00"..[[abcCc (['abcC', 'abcCl', 'abcCc'])
      ==
      =abcC
      abcCl
      abcCc=
      {{{2 setreg('D', 'abcDb', 'b')
      D: type ]].."\x165; value: abcD\x00abcDb (['abcD', 'abcDb']), expr: abcD\x00"..[[abcDb (['abcD', 'abcDb'])
      ==
      =abcD =
       abcDb
      {{{2 setreg('E', 'abcEb', 'b')
      E: type ]].."\x165; value: abcE\x00abcEb (['abcE', 'abcEb']), expr: abcE\x00"..[[abcEb (['abcE', 'abcEb'])
      ==
      =abcE =
       abcEb
      {{{2 setreg('E', 'abcEl', 'l')
      E: type V; value: abcE]].."\x00abcEb\x00abcEl\x00 (['abcE', 'abcEb', 'abcEl']), expr: abcE\x00abcEb\x00abcEl\x00"..[[ (['abcE', 'abcEb', 'abcEl'])
      ==
      abcE
      abcEb
      abcEl
      ==
      {{{2 setreg('F', 'abcFc', 'c')
      F: type v; value: abcF]].."\x00abcFc (['abcF', 'abcFc']), expr: abcF\x00"..[[abcFc (['abcF', 'abcFc'])
      ==
      =abcF
      abcFc=
      {{{1 Appending NL with setreg()
      {{{2 setreg('A', ']]..'\x00'..[[')
      A: type V; value: abcA2]].."\x00 (['abcA2']), expr: abcA2\x00"..[[ (['abcA2'])
      ==
      abcA2
      ==
      {{{2 setreg('B', ']]..'\x00'..[[', 'c')
      B: type v; value: abcB2]].."\x00 (['abcB2', '']), expr: abcB2\x00"..[[ (['abcB2', ''])
      ==
      =abcB2
      =
      {{{2 setreg('C', ']]..'\x00'..[[')
      C: type V; value: abcC2]].."\x00\x00 (['abcC2', '']), expr: abcC2\x00\x00"..[[ (['abcC2', ''])
      ==
      abcC2
      
      ==
      {{{2 setreg('D', ']]..'\x00'..[[', 'l')
      D: type V; value: abcD2]].."\x00\x00 (['abcD2', '']), expr: abcD2\x00\x00"..[[ (['abcD2', ''])
      ==
      abcD2
      
      ==
      {{{2 setreg('E', ']]..'\x00'..[[')
      E: type V; value: abcE2]].."\x00\x00 (['abcE2', '']), expr: abcE2\x00\x00"..[[ (['abcE2', ''])
      ==
      abcE2
      
      ==
      {{{2 setreg('F', ']]..'\x00'..[[', 'b')
      F: type ]].."\x160; value: abcF2\x00 (['abcF2', '']), expr: abcF2\x00"..[[ (['abcF2', ''])
      ==
      =abcF2=
       
      {{{1 Setting lists with setreg()
      {{{2 setreg('a', ['abcA3'], 'c')
      a: type v; value: abcA3 (['abcA3']), expr: abcA3 (['abcA3'])
      ==
      =abcA3=
      {{{2 setreg('b', ['abcB3'], 'l')
      b: type V; value: abcB3]].."\x00 (['abcB3']), expr: abcB3\x00"..[[ (['abcB3'])
      ==
      abcB3
      ==
      {{{2 setreg('c', ['abcC3'], 'b')
      c: type ]]..'\x16'..[[5; value: abcC3 (['abcC3']), expr: abcC3 (['abcC3'])
      ==
      =abcC3=
      {{{2 setreg('d', ['abcD3'])
      d: type V; value: abcD3]].."\x00 (['abcD3']), expr: abcD3\x00"..[[ (['abcD3'])
      ==
      abcD3
      ==
      {{{2 setreg('e', [1, 2, 'abc', 3])
      e: type V; value: 1]].."\x002\x00abc\x003\x00 (['1', '2', 'abc', '3']), expr: 1\x002\x00abc\x003\x00"..[[ (['1', '2', 'abc', '3'])
      ==
      1
      2
      abc
      3
      ==
      {{{2 setreg('f', [1, 2, 3])
      f: type V; value: 1]].."\x002\x003\x00 (['1', '2', '3']), expr: 1\x002\x003\x00"..[[ (['1', '2', '3'])
      ==
      1
      2
      3
      ==
      {{{1 Appending lists with setreg()
      {{{2 setreg('A', ['abcA3c'], 'c')
      A: type v; value: abcA3]].."\x00abcA3c (['abcA3', 'abcA3c']), expr: abcA3\x00"..[[abcA3c (['abcA3', 'abcA3c'])
      ==
      =abcA3
      abcA3c=
      {{{2 setreg('b', ['abcB3l'], 'la')
      b: type V; value: abcB3]].."\x00abcB3l\x00 (['abcB3', 'abcB3l']), expr: abcB3\x00abcB3l\x00"..[[ (['abcB3', 'abcB3l'])
      ==
      abcB3
      abcB3l
      ==
      {{{2 setreg('C', ['abcC3b'], 'lb')
      C: type ]].."\x166; value: abcC3\x00abcC3b (['abcC3', 'abcC3b']), expr: abcC3\x00"..[[abcC3b (['abcC3', 'abcC3b'])
      ==
      =abcC3 =
       abcC3b
      {{{2 setreg('D', ['abcD32'])
      D: type V; value: abcD3]].."\x00abcD32\x00 (['abcD3', 'abcD32']), expr: abcD3\x00abcD32\x00"..[[ (['abcD3', 'abcD32'])
      ==
      abcD3
      abcD32
      ==
      {{{2 setreg('A', ['abcA32'])
      A: type V; value: abcA3]].."\x00abcA3c\x00abcA32\x00 (['abcA3', 'abcA3c', 'abcA32']), expr: abcA3\x00abcA3c\x00abcA32\x00"..[[ (['abcA3', 'abcA3c', 'abcA32'])
      ==
      abcA3
      abcA3c
      abcA32
      ==
      {{{2 setreg('B', ['abcB3c'], 'c')
      B: type v; value: abcB3]].."\x00abcB3l\x00abcB3c (['abcB3', 'abcB3l', 'abcB3c']), expr: abcB3\x00abcB3l\x00"..[[abcB3c (['abcB3', 'abcB3l', 'abcB3c'])
      ==
      =abcB3
      abcB3l
      abcB3c=
      {{{2 setreg('C', ['abcC3l'], 'l')
      C: type V; value: abcC3]].."\x00abcC3b\x00abcC3l\x00 (['abcC3', 'abcC3b', 'abcC3l']), expr: abcC3\x00abcC3b\x00abcC3l\x00"..[[ (['abcC3', 'abcC3b', 'abcC3l'])
      ==
      abcC3
      abcC3b
      abcC3l
      ==
      {{{2 setreg('D', ['abcD3b'], 'b')
      D: type ]].."\x166; value: abcD3\x00abcD32\x00abcD3b (['abcD3', 'abcD32', 'abcD3b']), expr: abcD3\x00abcD32\x00"..[[abcD3b (['abcD3', 'abcD32', 'abcD3b'])
      ==
      =abcD3 =
       abcD32
       abcD3b
      {{{1 Appending lists with NL with setreg()
      {{{2 setreg('A', [']]..'\x00'..[[', 'abcA3l2'], 'l')
      A: type V; value: abcA3]].."\x00abcA3c\x00abcA32\x00\x00\x00abcA3l2\x00 (['abcA3', 'abcA3c', 'abcA32', '\x00', 'abcA3l2']), expr: abcA3\x00abcA3c\x00abcA32\x00\x00\x00abcA3l2\x00 (['abcA3', 'abcA3c', 'abcA32', '\x00"..[[', 'abcA3l2'])
      ==
      abcA3
      abcA3c
      abcA32
      ]]..'\x00'..[[
      abcA3l2
      ==
      {{{2 setreg('B', [']]..'\x00'..[[', 'abcB3c2'], 'c')
      B: type v; value: abcB3]].."\x00abcB3l\x00abcB3c\x00\x00\x00abcB3c2 (['abcB3', 'abcB3l', 'abcB3c', '\x00', 'abcB3c2']), expr: abcB3\x00abcB3l\x00abcB3c\x00\x00\x00abcB3c2 (['abcB3', 'abcB3l', 'abcB3c', '\x00"..[[', 'abcB3c2'])
      ==
      =abcB3
      abcB3l
      abcB3c
      ]]..'\x00'..[[
      abcB3c2=
      {{{2 setreg('C', [']]..'\x00'..[[', 'abcC3b2'], 'b')
      C: type ]].."\x167; value: abcC3\x00abcC3b\x00abcC3l\x00\x00\x00abcC3b2 (['abcC3', 'abcC3b', 'abcC3l', '\x00', 'abcC3b2']), expr: abcC3\x00abcC3b\x00abcC3l\x00\x00\x00abcC3b2 (['abcC3', 'abcC3b', 'abcC3l', '\x00"..[[', 'abcC3b2'])
      ==
      =abcC3  =
       abcC3b
       abcC3l
       ]]..'\x00'..[[
       abcC3b2
      {{{2 setreg('D', [']]..'\x00'..[[', 'abcD3b50'], 'b50')
      D: type ]].."\x1650; value: abcD3\x00abcD32\x00abcD3b\x00\x00\x00abcD3b50 (['abcD3', 'abcD32', 'abcD3b', '\x00', 'abcD3b50']), expr: abcD3\x00abcD32\x00abcD3b\x00\x00\x00abcD3b50 (['abcD3', 'abcD32', 'abcD3b', '\x00"..[[', 'abcD3b50'])
      ==
      =abcD3                                             =
       abcD32
       abcD3b
       ]]..'\x00'..[[
       abcD3b50
      {{{1 Setting lists with NLs with setreg()
      {{{2 setreg('a', ['abcA4-0', ']].."\x00', 'abcA4-2\x00', '\x00abcA4-3', 'abcA4-4\x00"..[[abcA4-4-2'])
      a: type V; value: abcA4-0]].."\x00\x00\x00abcA4-2\x00\x00\x00abcA4-3\x00abcA4-4\x00abcA4-4-2\x00 (['abcA4-0', '\x00', 'abcA4-2\x00', '\x00abcA4-3', 'abcA4-4\x00abcA4-4-2']), expr: abcA4-0\x00\x00\x00abcA4-2\x00\x00\x00abcA4-3\x00abcA4-4\x00abcA4-4-2\x00 (['abcA4-0', '\x00', 'abcA4-2\x00', '\x00abcA4-3', 'abcA4-4\x00"..[[abcA4-4-2'])
      ==
      abcA4-0
      ]]..'\x00'..[[
      abcA4-2]]..'\x00'..[[
      ]]..'\x00'..[[abcA4-3
      abcA4-4]]..'\x00'..[[abcA4-4-2
      ==
      {{{2 setreg('b', ['abcB4c-0', ']].."\x00', 'abcB4c-2\x00', '\x00abcB4c-3', 'abcB4c-4\x00"..[[abcB4c-4-2'], 'c')
      b: type v; value: abcB4c-0]].."\x00\x00\x00abcB4c-2\x00\x00\x00abcB4c-3\x00abcB4c-4\x00abcB4c-4-2 (['abcB4c-0', '\x00', 'abcB4c-2\x00', '\x00abcB4c-3', 'abcB4c-4\x00abcB4c-4-2']), expr: abcB4c-0\x00\x00\x00abcB4c-2\x00\x00\x00abcB4c-3\x00abcB4c-4\x00abcB4c-4-2 (['abcB4c-0', '\x00', 'abcB4c-2\x00', '\x00abcB4c-3', 'abcB4c-4\x00"..[[abcB4c-4-2'])
      ==
      =abcB4c-0
      ]]..'\x00'..[[
      abcB4c-2]]..'\x00'..[[
      ]]..'\x00'..[[abcB4c-3
      abcB4c-4]]..'\x00'..[[abcB4c-4-2=
      {{{2 setreg('c', ['abcC4l-0', ']].."\x00', 'abcC4l-2\x00', '\x00abcC4l-3', 'abcC4l-4\x00"..[[abcC4l-4-2'], 'l')
      c: type V; value: abcC4l-0]].."\x00\x00\x00abcC4l-2\x00\x00\x00abcC4l-3\x00abcC4l-4\x00abcC4l-4-2\x00 (['abcC4l-0', '\x00', 'abcC4l-2\x00', '\x00abcC4l-3', 'abcC4l-4\x00abcC4l-4-2']), expr: abcC4l-0\x00\x00\x00abcC4l-2\x00\x00\x00abcC4l-3\x00abcC4l-4\x00abcC4l-4-2\x00 (['abcC4l-0', '\x00', 'abcC4l-2\x00', '\x00abcC4l-3', 'abcC4l-4\x00"..[[abcC4l-4-2'])
      ==
      abcC4l-0
      ]]..'\x00'..[[
      abcC4l-2]]..'\x00'..[[
      ]]..'\x00'..[[abcC4l-3
      abcC4l-4]]..'\x00'..[[abcC4l-4-2
      ==
      {{{2 setreg('d', ['abcD4b-0', ']].."\x00', 'abcD4b-2\x00', '\x00abcD4b-3', 'abcD4b-4\x00"..[[abcD4b-4-2'], 'b')
      d: type ]].."\x1619; value: abcD4b-0\x00\x00\x00abcD4b-2\x00\x00\x00abcD4b-3\x00abcD4b-4\x00abcD4b-4-2 (['abcD4b-0', '\x00', 'abcD4b-2\x00', '\x00abcD4b-3', 'abcD4b-4\x00abcD4b-4-2']), expr: abcD4b-0\x00\x00\x00abcD4b-2\x00\x00\x00abcD4b-3\x00abcD4b-4\x00abcD4b-4-2 (['abcD4b-0', '\x00', 'abcD4b-2\x00', '\x00abcD4b-3', 'abcD4b-4\x00"..[[abcD4b-4-2'])
      ==
      =abcD4b-0           =
       ]]..'\x00'..[[
       abcD4b-2]]..'\x00'..[[
       ]]..'\x00'..[[abcD4b-3
       abcD4b-4]]..'\x00'..[[abcD4b-4-2
      {{{2 setreg('e', ['abcE4b10-0', ']].."\x00', 'abcE4b10-2\x00', '\x00abcE4b10-3', 'abcE4b10-4\x00"..[[abcE4b10-4-2'], 'b10')
      e: type ]].."\x1610; value: abcE4b10-0\x00\x00\x00abcE4b10-2\x00\x00\x00abcE4b10-3\x00abcE4b10-4\x00abcE4b10-4-2 (['abcE4b10-0', '\x00', 'abcE4b10-2\x00', '\x00abcE4b10-3', 'abcE4b10-4\x00abcE4b10-4-2']), expr: abcE4b10-0\x00\x00\x00abcE4b10-2\x00\x00\x00abcE4b10-3\x00abcE4b10-4\x00abcE4b10-4-2 (['abcE4b10-0', '\x00', 'abcE4b10-2\x00', '\x00abcE4b10-3', 'abcE4b10-4\x00"..[[abcE4b10-4-2'])
      ==
      =abcE4b10-0=
       ]]..'\x00'..[[
       abcE4b10-2]]..'\x00'..[[
       ]]..'\x00'..[[abcE4b10-3
       abcE4b10-4]]..'\x00'..[[abcE4b10-4-2
      {{{1 Search and expressions
      {{{2 setreg('/', ['abc/'])
      /: type v; value: abc/ (['abc/']), expr: abc/ (['abc/'])
      ==
      =abc/=
      {{{2 setreg('/', ['abc/]]..'\x00'..[['])
      /: type v; value: abc/]].."\x00 (['abc/\x00']), expr: abc/\x00 (['abc/\x00"..[['])
      ==
      =abc/]]..'\x00'..[[=
      {{{2 setreg('=', ['"abc/"'])
      =: type v; value: abc/ (['abc/']), expr: "abc/" (['"abc/"'])
      {{{2 setreg('=', ['"abc/]]..'\x00'..[["'])
      =: type v; value: abc/]].."\x00 (['abc/\x00"..[[']), expr: "abc/]]..'\x00'..[[" (['"abc/]]..'\x00'..[["'])
      {{{1 Errors
      Executing call setreg()
      Vim(call):E119: Not enough arguments for function: setreg
      Executing call setreg(1)
      Vim(call):E119: Not enough arguments for function: setreg
      Executing call setreg(1, 2, 3, 4)
      Vim(call):E118: Too many arguments for function: setreg
      Executing call setreg([], 2)
      Vim(call):E730: using List as a String
      Executing call setreg(1, {})
      Vim(call):E731: using Dictionary as a String
      Executing call setreg(1, 2, [])
      Vim(call):E730: using List as a String
      Executing call setreg("/", ["1", "2"])
      Vim(call):E883: search pattern and expression register may not contain two or more lines
      Executing call setreg("=", ["1", "2"])
      Vim(call):E883: search pattern and expression register may not contain two or more lines
      Executing call setreg(1, ["", "", [], ""])
      Vim(call):E730: using List as a String]])
  end)
end)
