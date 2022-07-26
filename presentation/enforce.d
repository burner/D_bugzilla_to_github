void enforce(bool cond, lazy string msg, string filename = __FILE__
		, int line = __LINE__) 
{
	if(!cond) {
		throw new Exception(msg, file, line);
	}
}
