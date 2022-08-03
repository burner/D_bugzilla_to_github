long[] splitIds(string page) {
	enum re = ctRegex!(`"show_bug.cgi\?id=[0-9]+"`);
	auto m = page.matchAll(re);

	long[] ret;
	foreach(it; m) {
		if(it.empty) {
			continue;
		}
		while(!it.empty && !(it.front >= '0' && it.front <= '9')) {
			it.popFront();
		}
		if(it.empty) {
			continue;
		}

		long num;
		long mul = 1;
		while(!it.empty && it.front >= '0' && it.front <= '9') {
			long t = (cast(char)it.front) - '0';
			num *= mul;
			num += t;
			mul *= 10;
			it.popFront();
		}

		if(mul == 1) {
			continue;
		}

		if(!ret.empty && ret[$ - 1] != num) {
			ret ~= num;
		}
	}
	return ret;
}
