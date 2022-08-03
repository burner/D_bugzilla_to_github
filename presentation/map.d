import std.traits : ReturnType;

auto map(alias Func,S)(S[] input) {
	alias R = typeof(Func(S.init));
	R[] ret;
	foreach(s; input) {
		ret ~= Func(s);
	}
	return ret;
}

unittest {
	import std.stdio;
	auto r = [1,2,3,4].map!(a => a * a);
	writeln(r);
}
