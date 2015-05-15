-- Test for writing and reading a file starting with a BOM

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('42', function()
  setup(clear)

  it('is working', function()
    insert([=[
      latin-1
      ��latin-1
      utf-8
      ﻿utf-8
      utf-8-err
      ﻿utf-8�err
      ucs-2
      �� u c s - 2 
      ucs-2le
      ��u c s - 2 l e 
      ucs-4
        ��   u   c   s   -   4   
      ucs-4le
      ��  u   c   s   -   4   l   e   ]=])

    execute('so mbyte.vim')
    execute('set encoding=utf-8')
    execute('set fileencodings=ucs-bom,latin-1')
    -- This changes the file for DOS and MAC.
    execute('set ff=unix ffs=unix')
    -- --- Write the test files.
    execute('/^latin-1$/+1w! Xtest0')
    execute('/^utf-8$/+1w! Xtest1')
    execute('/^utf-8-err$/+1w! Xtest2')
    execute('/^ucs-2$/+1w! Xtest3')
    execute('/^ucs-2le$/+1w! Xtest4')
    -- Need to add a NUL byte after the NL byte.
    execute('set bin')
    -- Ignore change from setting 'ff'.
    execute('e! Xtest4')
    feed('o <esc>:set noeol<cr>')
    execute('w')
    -- Allow default test42.in format.
    execute('set ffs& nobinary')
    execute('e #')
    -- Format for files to write.
    execute('set ff=unix')
    execute('/^ucs-4$/+1w! Xtest5')
    execute('/^ucs-4le$/+1w! Xtest6')
    -- Need to add three NUL bytes after the NL byte.
    execute('set bin')
    -- ! for when setting 'ff' is a change.
    execute('e! Xtest6')
    feed('o   <esc>:set noeol<cr>')
    execute('w')
    execute('set nobin')
    execute('e #')

    -- --- Check that editing a latin-1 file doesn't see a BOM.
    execute('e! Xtest0')
    execute('redir! >test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set bomb fenc=latin-1')
    execute('w! Xtest0x')

    -- --- Check utf-8.
    execute('e! Xtest1')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=utf-8')
    execute('w! Xtest1x')

    -- --- Check utf-8 with an error (will fall back to latin-1).
    execute('e! Xtest2')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=utf-8')
    execute('w! Xtest2x')

    -- --- Check ucs-2.
    execute('e! Xtest3')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-2')
    execute('w! Xtest3x')

    -- --- Check ucs-2le.
    execute('e! Xtest4')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-2le')
    execute('w! Xtest4x')

    -- --- Check ucs-4.
    execute('e! Xtest5')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-4')
    execute('w! Xtest5x')

    -- --- Check ucs-4le.
    execute('e! Xtest6')
    execute('redir >>test.out')
    execute('set fileencoding bomb?')
    execute('redir END')
    execute('set fenc=latin-1')
    execute('w >>test.out')
    execute('set fenc=ucs-4le')
    execute('w! Xtest6x')

    -- --- Check the files written with BOM.
    execute('set bin')
    execute('e! test.out')
    execute('$r Xtest0x')
    execute('$r Xtest1x')
    execute('$r Xtest2x')
    execute('$r Xtest3x')
    execute('$r Xtest4x')
    execute('$r Xtest5x')
    execute('$r Xtest6x')
    -- Write the file in default format.
    execute('set nobin ff&')
    execute('w! test.out')
    execute('qa!')

    -- Assert buffer contents.
    expect([=[
      
      
        fileencoding=latin1
      nobomb
      ��latin-1
      
      
        fileencoding=utf-8
        bomb
      utf-8
      
      
        fileencoding=latin1
      nobomb
      ﻿utf-8�err
      
      
        fileencoding=utf-16
        bomb
      ucs-2
      
      
        fileencoding=utf-16le
        bomb
      ucs-2le
      
      
        fileencoding=ucs-4
        bomb
      ucs-4
      
      
        fileencoding=ucs-4le
        bomb
      ucs-4le
      ��latin-1
      ﻿utf-8
      ï»¿utf-8err
      �� u c s - 2 
      ��u c s - 2 l e 
       
        ��   u   c   s   -   4   
      ��  u   c   s   -   4   l   e   
         ]=])
  end)
end)
