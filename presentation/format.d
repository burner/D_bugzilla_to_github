assert(format("%s", Hello) == "Hello");
assert(format("%5.f", 1.3333333) == "1.33333");
assert(format("%2$s %1$s", "a", "b") == "b a");
assert(format("%,3d", 100000000) == "100,000,000");
assert(format("%(%s,%)", [1,2,3]) == "1,2,3");

struct Foo {
	int a;
}
assert(format("%s", Foo.init) == "Foo(0)");
