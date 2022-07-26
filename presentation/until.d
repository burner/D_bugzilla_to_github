T[] until(alias pred, T)(T[] input) {
	T[] ret;
	while(!input.empty && !pred(input.front)) {
		ret ~= input.front;
	}
	return ret;
}

