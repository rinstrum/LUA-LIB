------------------------------------------------------------------------------
-- Basic statistical data gathering.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local function zero(n)
    local r = {}
    for i = 1, n do
        table.insert(r, 0)
    end
    return r
end

local function sum(d, f)
    local cols = d.columns
    local r = zero(cols)
    for i = 1, #d do
        local datum = d[i]
        for j = 1, cols do
            r[j] = r[j] + f(datum[j], i, j)
        end
    end
    return r
end

local function map(d, f)
    local r = {}
    for i = 1, #d do
        table.insert(r, f(d[i], i))
    end
    return r
end

return function()
    local d = {}
    local _M = {}

------------------------------------------------------------------------------
-- Return the dimensions of the data set.
-- @return The number of rows
-- @return The number of columns
    function _M.size() return #d, d.columns end

------------------------------------------------------------------------------
-- Add a data point to the statistical accumulations
-- @return The number of data points present after this one is added.
    function _M.add(...)
        local datum = {...}
        if d.columns == nil then
            d.columns = #datum
        end
        if d.columns == #datum then
            table.insert(d, datum)
            for _, i in pairs({
                                "sigma", "sigma2",
                                "mean", "variance", "stddev",
                                "pop_variance", "pop_stddev", "r"
                              }) do
                d[i] = nil
            end
        end
        return #d
    end

------------------------------------------------------------------------------
-- Accumulate the sums of the data
-- @return A table containing sums for each column of data.
    function _M.sum()
        if d.sigma == nil then
            d.sigma = sum(d, function(x) return x end)
        end
        return d.sigma
    end

------------------------------------------------------------------------------
-- Accumulate the sums of the squares of the data
-- @return A table containing sums of squares for each column of data.
    function _M.sumSquares()
        if d.sigma2 == nil then
            d.sigma2 = sum(d, function(x) return x*x end)
        end
        return d.sigma2
    end

------------------------------------------------------------------------------
-- The mean of the data
-- @return A table containing the mean of each column of data.
    function _M.mean()
        if d.mean == nil then
            -- This isn't numerically stable but should be good enough for now
            local rn = 1/#d
            d.mean = map(_M.sum(), function(x) return x * rn end)
        end
        return d.mean
    end

------------------------------------------------------------------------------
-- The sample variance of the data
-- @return A table containing the sample variance of each column of data.
    function _M.variance()
        if d.variance == nil then
            local m, fac = _M.mean(), 1 / (#d -1)
            local sums = sum(d, function(x, _, j) local d = x - m[j] return d * d end)
            d.variance = map(sums, function(x) return x * fac end)
        end
        return d.variance
    end

------------------------------------------------------------------------------
-- The population variance of the data
-- @return A table containing the population variance of each column of data.
    function _M.population_variance()
        if d.pop_variance == nil then
            local m, fac = _M.mean(), 1 / #d
            local sums = sum(d, function(x, _, j) local d = x - m[j] return d * d end)
            d.pop_variance = map(sums, function(x) return x * fac end)
        end
        return d.pop_variance
    end

------------------------------------------------------------------------------
-- The sample standard deviation of the data
-- @return A table containing the sample standard deviation of each column of data.
    function _M.stddev()
        if d.stddev == nil then
            d.stddev = map(_M.variance(), math.sqrt)
        end
        return d.stddev
    end

------------------------------------------------------------------------------
-- The population standard deviation of the data
-- @return A table containing the population standard deviation of each column of data.
    function _M.population_stddev()
        if d.pop_stddev == nil then
            d.pop_stddev = map(_M.population_variance(), math.sqrt)
        end
        return d.pop_stddev
    end

------------------------------------------------------------------------------
-- The correlation coefficients for the data
-- @return A table containing the correlation between each column and the first.
    function _M.r()
        if d.r == nil then
            local m, sd = _M.mean(), _M.stddev()
            local f = 1 / ((#d - 1) * sd[1])
            local x1 = map(d, function(r) return r[1] - m[1] end)
            local fact = map(sd, function(x) return f / x end)
            local sums = sum(d, function(x, i, j) return x1[i] * (x - m[j]) end)
            d.r = map(sums, function(x, j) return x * fact[j] end)
        end
        return d.r
    end
    return _M
end
