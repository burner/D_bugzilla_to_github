import std.exception : enforce;

struct Zip(T,R) {
	T a;
	R b;
}

Zip!(T,R)[] zip(T,R)(T[] a, R[] b) {
	enforce(a.length == b.length);
	Zip!(T,R)[] ret;
	foreach(idx, it; a) {
		ret ~= Zip!(T,R)(it, b[idx]);
	}
	return ret;
}

unittest {
	import std.stdio;

	auto a = [1,2,3];
	auto b = ["one", "two", "three"];
	auto z = zip(a,b);

	writeln(z);
}
