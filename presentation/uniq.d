T[] uniq(alias pred, T)(T[] input) {
	T[] ret;
	foreach(idx, it; input) {
		if(idx == 0 || !pred(it, ret[idx - 1])) {
			ret ~= it;
		}
	}
	return ret;
}
