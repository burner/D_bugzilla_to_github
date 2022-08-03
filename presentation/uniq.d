T[] uniq(alias pred, T)(T[] input) {
	T[] ret;
	foreach(idx, it; input) {
		if(idx == 0 || !pred(it, ret[$ - 1])) {
			ret ~= it;
		}
	}
	return ret;
}

unittest {
	import std.stdio;
	auto u = [1,2,3,3,4].uniq!((a,b) => a == b);
	writeln(u);
}
