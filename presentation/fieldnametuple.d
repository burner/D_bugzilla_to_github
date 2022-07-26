struct Foo {
	int a;
	int foo() { return a; };
}

void main(string[] args)
{
	pragma(msg, Foo.tupleof.stringof);
}
