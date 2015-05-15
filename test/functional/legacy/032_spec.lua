-- Test for insert expansion
-- :se cpt=.,w
-- * add-expands (word from next line) from other window
-- * add-expands (current buffer first)
-- * Local expansion, ends in an empty line (unless it becomes a global expansion)
-- * starts Local and switches to global add-expansion
-- :se cpt=.,w,i
-- * i-add-expands and switches to local
-- * add-expands lines (it would end in an empty line if it didn't ignored it self)
-- :se cpt=kXtestfile
-- * checks k-expansion, and file expansion (use Xtest11 instead of test11,
-- * because TEST11.OUT may match first on DOS)
-- :se cpt=w
-- * checks make_cyclic in other window
-- :se cpt=u nohid
-- * checks unloaded buffer expansion
-- * checks adding mode abortion
-- :se cpt=t,d
-- * tag expansion, define add-expansion interrupted
-- * t-expansion

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('32', function()
  setup(clear)

  it('is working', function()
    insert([=[
      start of testfile
      run1
      run2
      end of testfile
      
      test11	36Gepeto	/Tag/
      asd	test11file	36G
      Makefile	to	run]=])

    execute('so small.vim')
    execute('se cpt=.,w ff=unix | $-2,$w!Xtestfile | set ff&')
    execute('se cot=')
    feed('nO#include "Xtestfile"<cr>')
    feed('ru<esc><cr>')
    feed('O<cr>')
    feed('<cr>')
    feed('<esc>')
    execute('se cpt=.,w,i')
    feed('kOM<cr>')
    feed('<esc>')
    execute('se cpt=kXtestfile')
    execute('w Xtest11.one')
    execute('w Xtest11.two')
    feed('O<esc>IX<esc>A<esc>')
    -- Use CTRL-X CTRL-F to complete Xtest11.one, remove it and then use.
    -- CTRL-X CTRL-F again to verify this doesn't cause trouble.
    feed('OX<esc>ddk<cr>')
    execute('se cpt=w')
    feed('OST<esc>')
    execute('se cpt=u nohid')
    feed('oOEN<cr>')
    feed('unl<esc>')
    execute([[se cpt=t,d def=^\\k* tags=Xtestfile notagbsearch]])
    feed('O<cr>')
    feed('a<esc>')
    execute('wq! test.out')

    -- Assert buffer contents.
    expect([=[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      Xtest11.two
      STARTTEST
      ENDTEST
      unless
      test11file	36Gepeto	/Tag/ asd
      asd
      run1 run2
      ]=])
  end)
end)
