import std.algorithm.iteration : filter;

T[] filter(Cond)(T[] input) {
	T[] ret;
	foreach(it; input) {
		if(Cond(it)) {
			ret ~= it;
		}
	}
	return ret;
}
