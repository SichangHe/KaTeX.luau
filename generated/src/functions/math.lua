-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/math.js
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local ParseError = require(script.Parent.Parent.ParseError).default -- Switching from text mode back to math mode
defineFunction({
	type = "styling",
	names = { "\\(", "$" },
	props = { numArgs = 0, allowedInText = true, allowedInMath = false },
	handler = function(self, ref0, args)
		local funcName, parser = ref0.funcName, ref0.parser
		local outerMode = parser.mode
		parser:switchMode("math")
		local close = if funcName == "\\(" then "\\)" else "$"
		local body = parser:parseExpression(false, close)
		parser:expect(close)
		parser:switchMode(outerMode)
		return { type = "styling", mode = parser.mode, style = "text", body = body }
	end,
}) -- Check for extra closing math delimiters
defineFunction({
	type = "text",
	-- Doesn't matter what this is.
	names = { "\\)", "\\]" },
	props = { numArgs = 0, allowedInText = true, allowedInMath = false },
	handler = function(self, context, args)
		error(ParseError.new(("Mismatched %s"):format(tostring(context.funcName))))
	end,
})
