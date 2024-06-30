-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/relax.js
--@flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
defineFunction({
	type = "internal",
	names = { "\\relax" },
	props = { numArgs = 0, allowedInText = true },
	handler = function(self, ref0)
		local parser = ref0.parser
		return { type = "internal", mode = parser.mode }
	end,
})
