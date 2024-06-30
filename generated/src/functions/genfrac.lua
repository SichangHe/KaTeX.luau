-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/genfrac.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local normalizeArgument = defineFunctionModule.normalizeArgument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local delimiter = require(script.Parent.Parent.delimiter).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local Style = require(script.Parent.Parent.Style).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local assert_ = require(script.Parent.Parent.utils).assert_
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local unitsModule = require(script.Parent.Parent.units)
local calculateSize = unitsModule.calculateSize
local makeEm = unitsModule.makeEm
local function adjustStyle(size, originalStyle)
	-- Figure out what style this fraction should be in based on the
	-- function used
	local style = originalStyle
	if size == "display" then
		-- Get display style as a default.
		-- If incoming style is sub/sup, use style.text() to get correct size.
		style = if style.id
				>= Style.SCRIPT.id --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
			then style:text()
			else Style.DISPLAY
	elseif size == "text" and style.size == Style.DISPLAY.size then
		-- We're in a \tfrac but incoming style is displaystyle, so:
		style = Style.TEXT
	elseif size == "script" then
		style = Style.SCRIPT
	elseif size == "scriptscript" then
		style = Style.SCRIPTSCRIPT
	end
	return style
end
local function htmlBuilder(group, options)
	-- Fractions are handled in the TeXbook on pages 444-445, rules 15(a-e).
	local style = adjustStyle(group.size, options.style)
	local nstyle = style:fracNum()
	local dstyle = style:fracDen()
	local newOptions
	newOptions = options:havingStyle(nstyle)
	local numerm = html:buildGroup(group.numer, newOptions, options)
	if Boolean.toJSBoolean(group.continued) then
		-- \cfrac inserts a \strut into the numerator.
		-- Get \strut dimensions from TeXbook page 353.
		local hStrut = 8.5 / options:fontMetrics().ptPerEm
		local dStrut = 3.5 / options:fontMetrics().ptPerEm
		numerm.height = if numerm.height
				< hStrut --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then hStrut
			else numerm.height
		numerm.depth = if numerm.depth
				< dStrut --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then dStrut
			else numerm.depth
	end
	newOptions = options:havingStyle(dstyle)
	local denomm = html:buildGroup(group.denom, newOptions, options)
	local rule
	local ruleWidth
	local ruleSpacing
	if Boolean.toJSBoolean(group.hasBarLine) then
		if Boolean.toJSBoolean(group.barSize) then
			ruleWidth = calculateSize(group.barSize, options)
			rule = buildCommon:makeLineSpan("frac-line", options, ruleWidth)
		else
			rule = buildCommon:makeLineSpan("frac-line", options)
		end
		ruleWidth = rule.height
		ruleSpacing = rule.height
	else
		rule = nil
		ruleWidth = 0
		ruleSpacing = options:fontMetrics().defaultRuleThickness
	end -- Rule 15b
	local numShift
	local clearance
	local denomShift
	if style.size == Style.DISPLAY.size or group.size == "display" then
		numShift = options:fontMetrics().num1
		if
			ruleWidth
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			clearance = 3 * ruleSpacing
		else
			clearance = 7 * ruleSpacing
		end
		denomShift = options:fontMetrics().denom1
	else
		if
			ruleWidth
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			numShift = options:fontMetrics().num2
			clearance = ruleSpacing
		else
			numShift = options:fontMetrics().num3
			clearance = 3 * ruleSpacing
		end
		denomShift = options:fontMetrics().denom2
	end
	local frac
	if not Boolean.toJSBoolean(rule) then
		-- Rule 15c
		local candidateClearance = numShift - numerm.depth - (denomm.height - denomShift)
		if
			candidateClearance
			< clearance --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		then
			numShift += 0.5 * (clearance - candidateClearance)
			denomShift += 0.5 * (clearance - candidateClearance)
		end
		frac = buildCommon:makeVList({
			positionType = "individualShift",
			children = {
				{ type = "elem", elem = denomm, shift = denomShift },
				{ type = "elem", elem = numerm, shift = -numShift },
			},
		}, options)
	else
		-- Rule 15d
		local axisHeight = options:fontMetrics().axisHeight
		if
			numShift - numerm.depth - (axisHeight + 0.5 * ruleWidth)
			< clearance --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		then
			numShift += clearance - (numShift - numerm.depth - (axisHeight + 0.5 * ruleWidth))
		end
		if
			axisHeight - 0.5 * ruleWidth - (denomm.height - denomShift)
			< clearance --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		then
			denomShift += clearance - (axisHeight - 0.5 * ruleWidth - (denomm.height - denomShift))
		end
		local midShift = -(axisHeight - 0.5 * ruleWidth)
		frac = buildCommon:makeVList({
			positionType = "individualShift",
			children = {
				{ type = "elem", elem = denomm, shift = denomShift },
				{ type = "elem", elem = rule, shift = midShift },
				{ type = "elem", elem = numerm, shift = -numShift },
			},
		}, options)
	end -- Since we manually change the style sometimes (with \dfrac or \tfrac),
	-- account for the possible size change here.
	newOptions = options:havingStyle(style)
	frac.height *= newOptions.sizeMultiplier / options.sizeMultiplier
	frac.depth *= newOptions.sizeMultiplier / options.sizeMultiplier -- Rule 15e
	local delimSize
	if style.size == Style.DISPLAY.size then
		delimSize = options:fontMetrics().delim1
	elseif style.size == Style.SCRIPTSCRIPT.size then
		delimSize = options:havingStyle(Style.SCRIPT):fontMetrics().delim2
	else
		delimSize = options:fontMetrics().delim2
	end
	local leftDelim
	local rightDelim
	if
		group.leftDelim == nil --[[ ROBLOX CHECK: loose equality used upstream ]]
	then
		leftDelim = html:makeNullDelimiter(options, { "mopen" })
	else
		leftDelim = delimiter:customSizedDelim(
			group.leftDelim,
			delimSize,
			true,
			options:havingStyle(style),
			group.mode,
			{ "mopen" }
		)
	end
	if Boolean.toJSBoolean(group.continued) then
		rightDelim = buildCommon:makeSpan({}) -- zero width for \cfrac
	elseif
		group.rightDelim == nil --[[ ROBLOX CHECK: loose equality used upstream ]]
	then
		rightDelim = html:makeNullDelimiter(options, { "mclose" })
	else
		rightDelim = delimiter:customSizedDelim(
			group.rightDelim,
			delimSize,
			true,
			options:havingStyle(style),
			group.mode,
			{ "mclose" }
		)
	end
	return buildCommon:makeSpan(
		Array.concat({ "mord" }, newOptions:sizingClasses(options)),
		{ leftDelim, buildCommon:makeSpan({ "mfrac" }, { frac }), rightDelim },
		options
	)
end
local function mathmlBuilder(group, options)
	local node = mathMLTree.MathNode.new(
		"mfrac",
		{ mml:buildGroup(group.numer, options), mml:buildGroup(group.denom, options) }
	)
	if not Boolean.toJSBoolean(group.hasBarLine) then
		node:setAttribute("linethickness", "0px")
	elseif Boolean.toJSBoolean(group.barSize) then
		local ruleWidth = calculateSize(group.barSize, options)
		node:setAttribute("linethickness", makeEm(ruleWidth))
	end
	local style = adjustStyle(group.size, options.style)
	if style.size ~= options.style.size then
		node = mathMLTree.MathNode.new("mstyle", { node })
		local isDisplay = if style.size == Style.DISPLAY.size then "true" else "false"
		node:setAttribute("displaystyle", isDisplay)
		node:setAttribute("scriptlevel", "0")
	end
	if
		group.leftDelim ~= nil --[[ ROBLOX CHECK: loose inequality used upstream ]]
		or group.rightDelim ~= nil --[[ ROBLOX CHECK: loose inequality used upstream ]]
	then
		local withDelims = {}
		if
			group.leftDelim ~= nil --[[ ROBLOX CHECK: loose inequality used upstream ]]
		then
			local leftOp = mathMLTree.MathNode.new(
				"mo",
				{ mathMLTree.TextNode.new(group.leftDelim:replace("\\", "")) }
			)
			leftOp:setAttribute("fence", "true")
			table.insert(withDelims, leftOp) --[[ ROBLOX CHECK: check if 'withDelims' is an Array ]]
		end
		table.insert(withDelims, node) --[[ ROBLOX CHECK: check if 'withDelims' is an Array ]]
		if
			group.rightDelim ~= nil --[[ ROBLOX CHECK: loose inequality used upstream ]]
		then
			local rightOp = mathMLTree.MathNode.new(
				"mo",
				{ mathMLTree.TextNode.new(group.rightDelim:replace("\\", "")) }
			)
			rightOp:setAttribute("fence", "true")
			table.insert(withDelims, rightOp) --[[ ROBLOX CHECK: check if 'withDelims' is an Array ]]
		end
		return mml:makeRow(withDelims)
	end
	return node
end
defineFunction({
	type = "genfrac",
	names = {
		"\\dfrac",
		"\\frac",
		"\\tfrac",
		"\\dbinom",
		"\\binom",
		"\\tbinom",
		"\\\\atopfrac",
		-- can’t be entered directly
		"\\\\bracefrac",
		"\\\\brackfrac", -- ditto
	},
	props = { numArgs = 2, allowedInArgument = true },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local numer = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local denom = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local hasBarLine
		local leftDelim = nil
		local rightDelim = nil
		local size = "auto"
		local condition_ = funcName
		if condition_ == "\\dfrac" or condition_ == "\\frac" or condition_ == "\\tfrac" then
			hasBarLine = true
		elseif condition_ == "\\\\atopfrac" then
			hasBarLine = false
		elseif condition_ == "\\dbinom" or condition_ == "\\binom" or condition_ == "\\tbinom" then
			hasBarLine = false
			leftDelim = "("
			rightDelim = ")"
		elseif condition_ == "\\\\bracefrac" then
			hasBarLine = false
			leftDelim = "\\{"
			rightDelim = "\\}"
		elseif condition_ == "\\\\brackfrac" then
			hasBarLine = false
			leftDelim = "["
			rightDelim = "]"
		else
			error(Error.new("Unrecognized genfrac command"))
		end
		local condition_ = funcName
		if condition_ == "\\dfrac" or condition_ == "\\dbinom" then
			size = "display"
		elseif condition_ == "\\tfrac" or condition_ == "\\tbinom" then
			size = "text"
		end
		return {
			type = "genfrac",
			mode = parser.mode,
			continued = false,
			numer = numer,
			denom = denom,
			hasBarLine = hasBarLine,
			leftDelim = leftDelim,
			rightDelim = rightDelim,
			size = size,
			barSize = nil,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineFunction({
	type = "genfrac",
	names = { "\\cfrac" },
	props = { numArgs = 2 },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local numer = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local denom = args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "genfrac",
			mode = parser.mode,
			continued = true,
			numer = numer,
			denom = denom,
			hasBarLine = true,
			leftDelim = nil,
			rightDelim = nil,
			size = "display",
			barSize = nil,
		}
	end,
}) -- Infix generalized fractions -- these are not rendered directly, but replaced
-- immediately by one of the variants above.
defineFunction({
	type = "infix",
	names = { "\\over", "\\choose", "\\atop", "\\brace", "\\brack" },
	props = { numArgs = 0, infix = true },
	handler = function(self, ref0)
		local parser, funcName, token = ref0.parser, ref0.funcName, ref0.token
		local replaceWith
		local condition_ = funcName
		if condition_ == "\\over" then
			replaceWith = "\\frac"
		elseif condition_ == "\\choose" then
			replaceWith = "\\binom"
		elseif condition_ == "\\atop" then
			replaceWith = "\\\\atopfrac"
		elseif condition_ == "\\brace" then
			replaceWith = "\\\\bracefrac"
		elseif condition_ == "\\brack" then
			replaceWith = "\\\\brackfrac"
		else
			error(Error.new("Unrecognized infix genfrac command"))
		end
		return { type = "infix", mode = parser.mode, replaceWith = replaceWith, token = token }
	end,
})
local stylArray = { "display", "text", "script", "scriptscript" }
local function delimFromValue(
	delimString: string
): string | nil --[[ ROBLOX CHECK: verify if `null` wasn't used differently than `undefined` ]]
	local delim = nil
	if
		delimString.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		delim = delimString
		delim = if delim == "." then nil else delim
	end
	return delim
end
defineFunction({
	type = "genfrac",
	names = { "\\genfrac" },
	props = {
		numArgs = 6,
		allowedInArgument = true,
		argTypes = { "math", "math", "size", "text", "math", "math" },
	},
	handler = function(self, ref0, args)
		local parser = ref0.parser
		local numer = args[
			5 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local denom = args[
			6 --[[ ROBLOX adaptation: added 1 to array index ]]
		] -- Look into the parse nodes to get the desired delimiters.
		local leftNode = normalizeArgument(args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		])
		local leftDelim = if leftNode.type == "atom" and leftNode.family == "open"
			then delimFromValue(leftNode.text)
			else nil
		local rightNode = normalizeArgument(args[
			2 --[[ ROBLOX adaptation: added 1 to array index ]]
		])
		local rightDelim = if rightNode.type == "atom" and rightNode.family == "close"
			then delimFromValue(rightNode.text)
			else nil
		local barNode = assertNodeType(
			args[
				3 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"size"
		)
		local hasBarLine
		local barSize = nil
		if Boolean.toJSBoolean(barNode.isBlank) then
			-- \genfrac acts differently than \above.
			-- \genfrac treats an empty size group as a signal to use a
			-- standard bar size. \above would see size = 0 and omit the bar.
			hasBarLine = true
		else
			barSize = barNode.value
			hasBarLine = barSize.number > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		end -- Find out if we want displaystyle, textstyle, etc.
		local size = "auto"
		local styl = args[
			4 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		if styl.type == "ordgroup" then
			if
				styl.body.length
				> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
			then
				local textOrd = assertNodeType(
					styl.body[
						1 --[[ ROBLOX adaptation: added 1 to array index ]]
					],
					"textord"
				)
				size = stylArray[tostring(Number(textOrd.text))]
			end
		else
			styl = assertNodeType(styl, "textord")
			size = stylArray[tostring(Number(styl.text))]
		end
		return {
			type = "genfrac",
			mode = parser.mode,
			numer = numer,
			denom = denom,
			continued = false,
			hasBarLine = hasBarLine,
			barSize = barSize,
			leftDelim = leftDelim,
			rightDelim = rightDelim,
			size = size,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
}) -- \above is an infix fraction that also defines a fraction bar size.
defineFunction({
	type = "infix",
	names = { "\\above" },
	props = { numArgs = 1, argTypes = { "size" }, infix = true },
	handler = function(self, ref0, args)
		local parser, funcName, token = ref0.parser, ref0.funcName, ref0.token
		return {
			type = "infix",
			mode = parser.mode,
			replaceWith = "\\\\abovefrac",
			size = assertNodeType(
				args[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				"size"
			).value,
			token = token,
		}
	end,
})
defineFunction({
	type = "genfrac",
	names = { "\\\\abovefrac" },
	props = { numArgs = 3, argTypes = { "math", "size", "math" } },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local numer = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local barSize = assert_(assertNodeType(
			args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"infix"
		).size)
		local denom = args[
			3 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local hasBarLine = barSize.number > 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		return {
			type = "genfrac",
			mode = parser.mode,
			numer = numer,
			denom = denom,
			continued = false,
			hasBarLine = hasBarLine,
			barSize = barSize,
			leftDelim = nil,
			rightDelim = nil,
			size = "auto",
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
