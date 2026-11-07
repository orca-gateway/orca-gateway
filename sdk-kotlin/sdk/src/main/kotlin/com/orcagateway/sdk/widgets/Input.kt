package com.orcagateway.sdk.widgets

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.TextStyleProps

/**
 * Flutter `TextField` (`_buildTextField` and `_OrcaTextField` in
 * input_builders.dart; Swift's `TextFieldNodeView`). The text lives in the
 * field. Each edit sets the page-state key `stateKey` when the node has one
 * (a prop the engine class does not declare; Flutter reads it anyway), then
 * fires `onChange` with `eventData: {value}`, Flutter's `onChanged` order.
 * The page's value is the store at `stateKey`, else the resolved `value`;
 * when it changes from elsewhere (a reset, another action) the field takes
 * it without firing and keeps the cursor if it still fits
 * (`didUpdateWidget`). A disabled or read-only field takes no edits.
 *
 * Without `decoration` the field is bare, Flutter's EditableText path
 * (16 sp black text, grey placeholder). With one it is Material 3's text
 * field decoration (the outlined one for `border: outline`, no line for
 * `none`): label, hint, prefix and suffix, helper or error text, fill,
 * content padding, and the `n/max` counter when `maxLength` is set. The
 * field fills the width it is given, as Flutter's does.
 * `enableSuggestions` has no Compose switch.
 */
@Composable
internal fun TextFieldWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val field = remember { FieldText(pageText(node, model)) }
    field.follow(pageText(node, model))

    val enabled = node["enabled"]?.boolValue ?: true
    val readOnly = node["readOnly"]?.boolValue ?: false
    val obscure = node["obscureText"]?.boolValue ?: false
    val maxLines = if (obscure) 1 else count(node["maxLines"]) ?: 1
    val maxLength = count(node["maxLength"])
    val decoration = node["decoration"]?.objectValue
    val placeholder = decoration?.get("hintText")?.stringValue ?: node["placeholder"]?.stringValue ?: ""
    val style = TextStyle(fontSize = 16.sp, color = Props.hex("#000000")).merge(TextStyleProps(node["style"]).textStyle())
    val visual = if (obscure) PasswordVisualTransformation() else VisualTransformation.None
    val interaction = remember { MutableInteractionSource() }
    val focus = remember { FocusRequester() }
    if (node["autofocus"]?.boolValue == true) LaunchedEffect(focus) { focus.requestFocus() }

    BasicTextField(
        value = field.value,
        onValueChange = { next ->
            val limited = limit(next, maxLength)
            val edited = limited.text != field.value.text
            field.value = limited
            if (edited) edit(node, model, limited.text)
        },
        modifier = modifier.fillMaxWidth().focusRequester(focus),
        enabled = enabled,
        readOnly = readOnly,
        textStyle = style,
        keyboardOptions = KeyboardOptions(
            autoCorrectEnabled = node["autocorrect"]?.boolValue ?: true,
            keyboardType = keyboardType(node["inputType"]?.stringValue, obscure),
            imeAction = imeAction(node["textInputAction"]?.stringValue),
        ),
        singleLine = maxLines == 1,
        maxLines = maxLines,
        visualTransformation = visual,
        interactionSource = interaction,
        cursorBrush = SolidColor(if (decoration == null) Props.hex("#2196F3") else MaterialTheme.colorScheme.primary),
        decorationBox = { inner ->
            if (decoration == null) {
                Box {
                    if (field.value.text.isEmpty() && placeholder.isNotEmpty()) {
                        BasicText(placeholder, style = style.merge(TextStyle(color = Props.hex("#9E9E9E"))))
                    }
                    inner()
                }
            } else {
                Decorated(
                    decoration,
                    FieldState(field.value.text, placeholder, enabled, maxLines == 1, visual, interaction, maxLength),
                    inner,
                )
            }
        },
    )
}

/**
 * One edit, Flutter's `onChanged`: the page-state key `stateKey` first,
 * then `onChange` with `{value}`. A field with neither fires nothing.
 */
private fun edit(node: ResolvedNode, model: OrcaPageModel, text: String) {
    val value = JsonValue.String(text)
    node["stateKey"]?.stringValue?.let { key -> model.store.dispatch(mapOf(key to value)) }
    model.fire("onChange", on = node, eventData = mapOf("value" to value))
}

/** The page's value: the store at `stateKey`, else the resolved `value` (Flutter `_buildTextField`). */
private fun pageText(node: ResolvedNode, model: OrcaPageModel): String {
    val key = node["stateKey"]?.stringValue ?: return Props.text(node["value"])
    return Props.text(model.store.value(key))
}

/** A positive count (`maxLines`, `maxLength`); anything else null. */
private fun count(value: JsonValue?): Int? = value?.intValue?.takeIf { it > 0 }?.coerceAtMost(Int.MAX_VALUE.toLong())?.toInt()

/** Cut an edit to `maxLength` characters (Flutter's `LengthLimitingTextInputFormatter`). */
private fun limit(value: TextFieldValue, maxLength: Int?): TextFieldValue {
    if (maxLength == null || value.text.length <= maxLength) return value
    val text = value.text.take(maxLength)
    return TextFieldValue(text, TextRange(value.selection.start.coerceAtMost(text.length), value.selection.end.coerceAtMost(text.length)))
}

/**
 * Flutter `_parseInputType`. An obscured field asks for a password
 * keyboard, as Flutter's Android text input does for `obscureText`.
 */
private fun keyboardType(inputType: String?, obscure: Boolean): KeyboardType = when (inputType) {
    "number" -> if (obscure) KeyboardType.NumberPassword else KeyboardType.Number
    "email" -> KeyboardType.Email
    "phone" -> KeyboardType.Phone
    "url" -> KeyboardType.Uri
    else -> if (obscure) KeyboardType.Password else KeyboardType.Text
}

/** Flutter `_parseTextInputAction`, as far as Compose's IME actions go. */
private fun imeAction(action: String?): ImeAction = when (action) {
    "done" -> ImeAction.Done
    "go" -> ImeAction.Go
    "search" -> ImeAction.Search
    "send" -> ImeAction.Send
    "next" -> ImeAction.Next
    "previous" -> ImeAction.Previous
    "none" -> ImeAction.None
    else -> ImeAction.Default
}

/**
 * The field's own text (Flutter's controller) and the page value it last
 * took (`oldWidget.value`).
 */
private class FieldText(seed: String) {
    var value: TextFieldValue by mutableStateOf(TextFieldValue(seed, TextRange(seed.length)))
    private var page = seed

    /** Take the page's value when it changed from elsewhere, keeping the cursor if it still fits. */
    fun follow(next: String) {
        if (next == page) return
        page = next
        if (next == value.text) return
        val selection = value.selection
        value = TextFieldValue(next, if (selection.max <= next.length) selection else TextRange(next.length))
    }
}

/** What the decoration needs to know about the field. */
private class FieldState(
    val text: String,
    val placeholder: String,
    val enabled: Boolean,
    val singleLine: Boolean,
    val visual: VisualTransformation,
    val interaction: MutableInteractionSource,
    val maxLength: Int?,
)

/**
 * Flutter `InputDecoration` (`parseInputDecoration`) as Material 3's text
 * field decoration: `border` `outline` is the outlined one, `underline`
 * (the default) the filled one's line, `none` no line; the fill only when
 * `filled` (`fillColor`, else #F5F5F5).
 */
@Composable
private fun Decorated(decoration: Map<String, JsonValue>, field: FieldState, inner: @Composable () -> Unit) {
    val error = decoration["errorText"]?.stringValue
    val helper = decoration["helperText"]?.stringValue
    val labelText = decoration["labelText"]?.stringValue
    val labelStyle = TextStyleProps(decoration["labelStyle"]).textStyle()
    val border = decoration["border"]?.stringValue
    val fill = if (decoration["filled"]?.boolValue == true) {
        Props.color(decoration["fillColor"]) ?: Props.hex("#F5F5F5")
    } else {
        Color.Transparent
    }
    val padding: PaddingValues? = Props.insets(decoration["contentPadding"])?.paddingValues()

    val label: (@Composable () -> Unit)? = labelText?.let { { Text(it, style = LocalTextStyle.current.merge(labelStyle)) } }
    val hint: (@Composable () -> Unit)? = field.placeholder.takeIf { it.isNotEmpty() }?.let { { Text(it) } }
    val prefix: (@Composable () -> Unit)? = decoration["prefixText"]?.stringValue?.let { { Text(it) } }
    val suffix: (@Composable () -> Unit)? = decoration["suffixText"]?.stringValue?.let { { Text(it) } }
    val supporting: (@Composable () -> Unit)? = if (error != null || helper != null || field.maxLength != null) {
        {
            Row {
                Text(error ?: helper ?: "", Modifier.weight(1f))
                if (field.maxLength != null) Text("${field.text.length}/${field.maxLength}")
            }
        }
    } else {
        null
    }

    if (border == "outline") {
        OutlinedTextFieldDefaults.DecorationBox(
            value = field.text,
            innerTextField = inner,
            enabled = field.enabled,
            singleLine = field.singleLine,
            visualTransformation = field.visual,
            interactionSource = field.interaction,
            isError = error != null,
            label = label,
            placeholder = hint,
            prefix = prefix,
            suffix = suffix,
            supportingText = supporting,
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = fill,
                unfocusedContainerColor = fill,
                disabledContainerColor = fill,
                errorContainerColor = fill,
            ),
            contentPadding = padding ?: OutlinedTextFieldDefaults.contentPadding(),
        )
    } else {
        val line = if (border == "none") Color.Transparent else Color.Unspecified
        TextFieldDefaults.DecorationBox(
            value = field.text,
            innerTextField = inner,
            enabled = field.enabled,
            singleLine = field.singleLine,
            visualTransformation = field.visual,
            interactionSource = field.interaction,
            isError = error != null,
            label = label,
            placeholder = hint,
            prefix = prefix,
            suffix = suffix,
            supportingText = supporting,
            colors = TextFieldDefaults.colors(
                focusedContainerColor = fill,
                unfocusedContainerColor = fill,
                disabledContainerColor = fill,
                errorContainerColor = fill,
                focusedIndicatorColor = line,
                unfocusedIndicatorColor = line,
                disabledIndicatorColor = line,
                errorIndicatorColor = line,
            ),
            contentPadding = padding ?: if (label == null) {
                TextFieldDefaults.contentPaddingWithoutLabel()
            } else {
                TextFieldDefaults.contentPaddingWithLabel()
            },
        )
    }
}
