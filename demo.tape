Output demo.gif

Set FontSize 12
Set Width 1512
Set Height 920
Set Theme "Builtin Solarized Dark"
Set Padding 28
Set TypingSpeed 0ms

Type "clear"
Enter
Sleep 300ms

Type "rm -f demo-q2.rb demo-q3.rb"
Enter
Sleep 300ms

Type "printf 'Bulbasaur -> Charmander'"
Enter
Sleep 500ms

Type "ruby quine.rb"
Enter
Sleep 1500ms

Type "clear"
Enter
Sleep 300ms

Type "printf 'Charmander -> Squirtle'"
Enter
Sleep 500ms

Type "ruby quine.rb > demo-q2.rb && ruby demo-q2.rb"
Enter
Sleep 1500ms

Type "clear"
Enter
Sleep 300ms

Type "printf 'Squirtle -> Bulbasaur'"
Enter
Sleep 500ms

Type "ruby quine.rb > demo-q2.rb && ruby demo-q2.rb > demo-q3.rb && ruby demo-q3.rb"
Enter
Sleep 1500ms

Type "clear"
Enter
Sleep 300ms

Type "ruby test_quine.rb"
Enter
Sleep 2s

Type "rm -f demo-q2.rb demo-q3.rb"
Enter
Sleep 300ms
