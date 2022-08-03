T[] filter(alias Cond,T)(T[] input) {
	T[] ret;
	foreach(it; input) {
		if(Cond(it)) {
			ret ~= it;
		}
	}
	return ret;
}

unittest {
	import std.algorithm : equal;
	import std.stdio;
	auto even = [1,2,3,4].filter!(it => it % 2 == 0);
	writeln(even);
}
