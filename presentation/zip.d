struct Zip(T,R) {
	T a;
	R b;
}

Zip!(T,R) zip(T,R)(T[] a, R[] b) {
	enforce(a.length == b.length);
	Zip[] ret;
	foreach(idx, it; a) {
		ret ~= Zip(it, b[idx]);
	}
	return ret;
}
