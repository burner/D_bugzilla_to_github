template ElementEncodingTypeEasy(T) {
	alias ElementEncodingTypeEasy = typeof(T.front);
}

unittest {
	static assert(is(ElementEncodingTypeEasy!(string) == dchar)); // fails
}

T front(T[] t) {
	return t[0];
}

unittest {
	string t = "ÄÖ";
	assert(t.front() = '\U000000E4');
}

template ElementEncodingType(T) {
	static if(isSomeString!(T))
		alias ElementEncodingType = dchar;
	else
		alias ElementEncodingType = typeof(T.front);
}
