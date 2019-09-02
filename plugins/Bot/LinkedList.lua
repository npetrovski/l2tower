LinkedList = {
	first = nil;
	last = nil;
}
LinkedList_mt = {__index=LinkedList}

function LinkedList:new(o)
	return setmetatable(o or {}, LinkedList_mt);
end

function LinkedList:any()
	return self.last or self.first;
end

function LinkedList:getLast()
	return self.last;
end

function LinkedList:getFirst()
	return self.first;
end

function LinkedList:addFirst(element)
	if self.first then
		self.first.listNext = element
		element.listPrev = self.first;
	else
		self.last = element;
	end
	self.first = element
end

function LinkedList:addLast(element)
	if self.last then
		self.last.listPrev = element
		element.listNext = self.last;
	else
		self.first = element;
	end
	self.last = element
end

function LinkedList:popLast()
	local res = self.last;
	if res then
		self.last = res.listNext;
		if not self.last then
			self.first = nil;
		end
		res.listNext = nil
		res.listPrev = nil
		return res;
	end
end

function LinkedList:iterateRev(startFrom)
	local cur;
	local nxt = startFrom or self:getLast()
	return function ()
		cur = nxt;
		if not cur then
			return; end
		nxt = cur.listNext;
		return cur;
	end
end

function LinkedList:iterate(startFrom)
	local cur;
	local nxt = startFrom or self:getFirst()
	return function ()
		cur = nxt;
		if not cur then
			return; end
		nxt = cur.listPrev;
		return cur;
	end
end

-- local path = LinkedList:new()

-- path:addFirst({})
-- path:addFirst({})

-- print("last", path:getLast())

-- path:popLast()
-- path:popLast()

-- path:addFirst({})

-- print("last", path:getLast())