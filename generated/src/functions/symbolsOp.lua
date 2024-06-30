-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/symbolsOp.js
-- @flow
local defineFunctionBuilders = require(script.Parent.Parent.defineFunction).defineFunctionBuilders
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local mml = require(script.Parent.Parent.buildMathML) -- Operator ParseNodes created in Parser.js from symbol Groups in src/symbols.js.
defineFunctionBuilders({
	type = "atom",
	htmlBuilder = function(self, group, options)
		return buildCommon:mathsym(
			group.text,
			group.mode,
			options,
			{ "m" .. tostring(group.family) }
		)
	end,
	mathmlBuilder = function(self, group, options)
		local node = mathMLTree.MathNode.new("mo", { mml:makeText(group.text, group.mode) })
		if group.family == "bin" then
			local variant = mml:getVariant(group, options)
			if variant == "bold-italic" then
				node:setAttribute("mathvariant", variant)
			end
		elseif group.family == "punct" then
			node:setAttribute("separator", "true")
		elseif group.family == "open" or group.family == "close" then
			-- Delims built here should not stretch vertically.
			-- See delimsizing.js for stretchy delims.
			node:setAttribute("stretchy", "false")
		end
		return node
	end,
})
