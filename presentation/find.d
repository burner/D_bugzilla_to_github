import std.range;

T[] find(alias pred, T)(T[] input) {
	while(!input.empty && !pred(input.front)) {
		input.popFront();
	}
	return input;
}

unittest {
	import std.stdio;
	auto f = [1,2,3,4].find!(it => it == 2);
	writeln(f);
}
