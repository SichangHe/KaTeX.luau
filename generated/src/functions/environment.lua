-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/environment.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local ParseError = require(script.Parent.Parent.ParseError).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local environments = require(script.Parent.Parent.environments).default -- Environment delimiters. HTML/MathML rendering is defined in the corresponding
-- defineEnvironment definitions.
defineFunction({
	type = "environment",
	names = { "\\begin", "\\end" },
	props = { numArgs = 1, argTypes = { "text" } },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local nameGroup = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		if nameGroup.type ~= "ordgroup" then
			error(ParseError.new("Invalid environment name", nameGroup))
		end
		local envName = ""
		do
			local i = 0
			while
				i
				< nameGroup.body.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				envName += assertNodeType(nameGroup.body[tostring(i)], "textord").text
				i += 1
			end
		end
		if funcName == "\\begin" then
			-- begin...end is similar to left...right
			if not Boolean.toJSBoolean(environments:hasOwnProperty(envName)) then
				error(ParseError.new("No such environment: " .. tostring(envName), nameGroup))
			end -- Build the environment object. Arguments and other information will
			-- be made available to the begin and end methods using properties.
			local env = environments[tostring(envName)]
			local args, optArgs
			do
				local ref = parser:parseArguments("\\begin{" .. tostring(envName) .. "}", env)
				args, optArgs = ref.args, ref.optArgs
			end
			local context = { mode = parser.mode, envName = envName, parser = parser }
			local result = env:handler(context, args, optArgs)
			parser:expect("\\end", false)
			local endNameToken = parser.nextToken
			local end_ = assertNodeType(parser:parseFunction(), "environment")
			if end_.name ~= envName then
				error(
					ParseError.new(
						("Mismatch: \\begin{%s} matched by \\end{%s}"):format(
							tostring(envName),
							tostring(end_.name)
						),
						endNameToken
					)
				)
			end -- $FlowFixMe, "environment" handler returns an environment ParseNode
			return result
		end
		return { type = "environment", mode = parser.mode, name = envName, nameGroup = nameGroup }
	end,
})
