ba : lex.yy.c
	gcc lex.yy.c -o ba -lfl

lex.yy.c : ba.l
	flex ba.l

clean :
	rm ba lex.yy.c