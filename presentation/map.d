import std.algorithm.iteration : map;

T[] map(Func,S)(S[] input) {
	T[] ret;
	foreach(s; input) {
		ret ~= Func(s);
	}
	return ret;
}
