T[] find(alias pred, T)(T[] input) {
	while(!input.empty && !pred(input.front)) {
		input.popFront();
	}
	return input;
}
