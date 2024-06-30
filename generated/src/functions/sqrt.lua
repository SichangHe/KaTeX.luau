-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/sqrt.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local delimiter = require(script.Parent.Parent.delimiter).default
local Style = require(script.Parent.Parent.Style).default
local makeEm = require(script.Parent.Parent.units).makeEm
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
defineFunction({
	type = "sqrt",
	names = { "\\sqrt" },
	props = { numArgs = 1, numOptionalArgs = 1 },
	handler = function(self, ref0, args, optArgs)
		local parser = ref0.parser
		local index = optArgs[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return { type = "sqrt", mode = parser.mode, body = body, index = index }
	end,
	htmlBuilder = function(self, group, options)
		-- Square roots are handled in the TeXbook pg. 443, Rule 11.
		-- First, we do the same steps as in overline to build the inner group
		-- and line
		local inner = html:buildGroup(group.body, options:havingCrampedStyle())
		if inner.height == 0 then
			-- Render a small surd.
			inner.height = options:fontMetrics().xHeight
		end -- Some groups can return document fragments.  Handle those by wrapping
		-- them in a span.
		inner = buildCommon:wrapFragment(inner, options) -- Calculate the minimum size for the \surd delimiter
		local metrics = options:fontMetrics()
		local theta = metrics.defaultRuleThickness
		local phi = theta
		if
			options.style.id
			< Style.TEXT.id --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		then
			phi = options:fontMetrics().xHeight
		end -- Calculate the clearance between the body and line
		local lineClearance = theta + phi / 4
		local minDelimiterHeight = inner.height + inner.depth + lineClearance + theta -- Create a sqrt SVG of the required minimum size
		local img, ruleWidth, advanceWidth
		do
			local ref = delimiter:sqrtImage(minDelimiterHeight, options)
			img, ruleWidth, advanceWidth = ref.span, ref.ruleWidth, ref.advanceWidth
		end
		local delimDepth = img.height - ruleWidth -- Adjust the clearance based on the delimiter size
		if
			delimDepth
			> inner.height + inner.depth + lineClearance --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			lineClearance = (lineClearance + delimDepth - inner.height - inner.depth) / 2
		end -- Shift the sqrt image
		local imgShift = img.height - inner.height - lineClearance - ruleWidth
		inner.style.paddingLeft = makeEm(advanceWidth) -- Overlay the image and the argument.
		local body = buildCommon:makeVList({
			positionType = "firstBaseline",
			children = {
				{ type = "elem", elem = inner, wrapperClasses = { "svg-align" } },
				{ type = "kern", size = -(inner.height + imgShift) },
				{ type = "elem", elem = img },
				{ type = "kern", size = ruleWidth },
			},
		}, options)
		if not Boolean.toJSBoolean(group.index) then
			return buildCommon:makeSpan({ "mord", "sqrt" }, { body }, options)
		else
			-- Handle the optional root index
			-- The index is always in scriptscript style
			local newOptions = options:havingStyle(Style.SCRIPTSCRIPT)
			local rootm = html:buildGroup(group.index, newOptions, options) -- The amount the index is shifted by. This is taken from the TeX
			-- source, in the definition of `\r@@t`.
			local toShift = 0.6 * (body.height - body.depth) -- Build a VList with the superscript shifted up correctly
			local rootVList = buildCommon:makeVList({
				positionType = "shift",
				positionData = -toShift,
				children = { { type = "elem", elem = rootm } },
			}, options) -- Add a class surrounding it so we can add on the appropriate
			-- kerning
			local rootVListWrap = buildCommon:makeSpan({ "root" }, { rootVList })
			return buildCommon:makeSpan({ "mord", "sqrt" }, { rootVListWrap, body }, options)
		end
	end,
	mathmlBuilder = function(self, group, options)
		local body, index = group.body, group.index
		return if Boolean.toJSBoolean(index)
			then mathMLTree.MathNode.new(
				"mroot",
				{ mml:buildGroup(body, options), mml:buildGroup(index, options) }
			)
			else mathMLTree.MathNode.new("msqrt", { mml:buildGroup(body, options) })
	end,
})
