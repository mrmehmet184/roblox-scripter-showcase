--!strict

export type Bucket = {
	windowStartedAt: number,
	count: number,
}

type InternalRateLimiter = {
	_buckets: { [Player]: { [string]: Bucket } },
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: InternalRateLimiter, RateLimiter))

function RateLimiter.new(): RateLimiter
	return setmetatable({
		_buckets = {},
	}, RateLimiter)
end

function RateLimiter:Allow(player: Player, key: string, limit: number, windowSeconds: number): boolean
	local now = os.clock()
	local playerBuckets = self._buckets[player]

	if playerBuckets == nil then
		playerBuckets = {}
		self._buckets[player] = playerBuckets
	end

	local bucket = playerBuckets[key]
	if bucket == nil or now - bucket.windowStartedAt >= windowSeconds then
		playerBuckets[key] = {
			windowStartedAt = now,
			count = 1,
		}
		return true
	end

	if bucket.count >= limit then
		return false
	end

	bucket.count += 1
	return true
end

function RateLimiter:Forget(player: Player)
	self._buckets[player] = nil
end

function RateLimiter:Destroy()
	table.clear(self._buckets)
end

return RateLimiter
