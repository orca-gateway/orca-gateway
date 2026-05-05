import 'package:flutter/material.dart'
    show
        TextInputType,
        TextField,
        Material,
        MaterialType,
        Slider,
        SliderTheme,
        Checkbox,
        CheckboxListTile,
        Switch,
        SwitchListTile,
        ListTileControlAffinity,
        TextInputAction,
        Theme,
        ThemeData,
        InputDecoration;
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter/widgets.dart';
import '../rendering/component_context.dart';
import '../rendering/component_registry.dart';
import 'builder_helpers.dart';

/// Register all input component builders.
void registerInputBuilders(ComponentRegistry registry) {
  registry.register('TextField', _buildTextField);
  registry.register('TextFormField', _buildTextFormField);
  registry.register('Checkbox', _buildCheckbox);
  registry.register('Radio', _buildRadio);
  registry.register('Switch', _buildSwitch);
  registry.register('Slider', _buildSlider);
}

Widget _buildTextField(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final stateKey = ctx.prop<String>('stateKey');
  final value = stateKey != null
      ? (ctx.stateGet(stateKey)?.toString() ?? '')
      : resolveStringValue(ctx.prop('value'), ctx.state);
  final obscure = ctx.propOr<bool>('obscureText', false);
  final maxLines = ctx.propOr<int>('maxLines', 1);
  final maxLength = ctx.prop<int>('maxLength');
  final placeholder = ctx.prop<String>('placeholder');
  final style = parseTextStyle(ctx.prop('style'));
  final inputType = _parseInputType(ctx.prop<String>('inputType'));
  final autofocus = ctx.propOr<bool>('autofocus', false);
  final readOnly = ctx.propOr<bool>('readOnly', false);
  final autocorrect = ctx.propOr<bool>('autocorrect', true);
  final enableSuggestions = ctx.propOr<bool>('enableSuggestions', true);
  final textInputAction = _parseTextInputAction(
    ctx.prop<String>('textInputAction'),
  );
  final decoration = parseInputDecoration(ctx.prop('decoration'));

  return _OrcaTextField(
    key: ValueKey('tf_${ctx.node.id}'),
    value: value,
    enabled: enabled,
    obscureText: obscure,
    maxLines: maxLines,
    maxLength: maxLength,
    placeholder: placeholder,
    style: style,
    keyboardType: inputType,
    autofocus: autofocus,
    readOnly: readOnly,
    autocorrect: autocorrect,
    enableSuggestions: enableSuggestions,
    textInputAction: textInputAction,
    decoration: decoration,
    onChanged: enabled
        ? (newValue) {
            if (stateKey != null && ctx.actionExecutor != null) {
              ctx.actionExecutor!.execute({
                'type': 'setState',
                'key': stateKey,
                'value': newValue,
              });
            }
            ctx.fireAction('onChange', eventData: {'value': newValue});
          }
        : null,
  );
}

Widget _buildTextFormField(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final stateKey = ctx.prop<String>('stateKey');
  final value = stateKey != null
      ? (ctx.stateGet(stateKey)?.toString() ?? '')
      : resolveStringValue(ctx.prop('value'), ctx.state);
  final obscure = ctx.propOr<bool>('obscureText', false);
  final maxLines = ctx.propOr<int>('maxLines', 1);
  final maxLength = ctx.prop<int>('maxLength');
  final placeholder = ctx.prop<String>('placeholder');
  final style = parseTextStyle(ctx.prop('style'));
  final inputType = _parseInputType(ctx.prop<String>('inputType'));
  final autofocus = ctx.propOr<bool>('autofocus', false);
  final readOnly = ctx.propOr<bool>('readOnly', false);
  final autocorrect = ctx.propOr<bool>('autocorrect', true);
  final enableSuggestions = ctx.propOr<bool>('enableSuggestions', true);
  final textInputAction = _parseTextInputAction(
    ctx.prop<String>('textInputAction'),
  );
  final decoration = parseInputDecoration(ctx.prop('decoration'));

  // TextFormField reuses the same stateful wrapper as TextField.
  return _OrcaTextField(
    key: ValueKey('tff_${ctx.node.id}'),
    value: value,
    enabled: enabled,
    obscureText: obscure,
    maxLines: maxLines,
    maxLength: maxLength,
    placeholder: placeholder,
    style: style,
    keyboardType: inputType,
    autofocus: autofocus,
    readOnly: readOnly,
    autocorrect: autocorrect,
    enableSuggestions: enableSuggestions,
    textInputAction: textInputAction,
    decoration: decoration,
    onChanged: enabled
        ? (newValue) {
            if (stateKey != null && ctx.actionExecutor != null) {
              ctx.actionExecutor!.execute({
                'type': 'setState',
                'key': stateKey,
                'value': newValue,
              });
            }
            ctx.fireAction('onChange', eventData: {'value': newValue});
          }
        : null,
  );
}

Widget _buildRadio(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final stateKey = ctx.prop<String>('stateKey');
  final value = resolveStringValue(ctx.prop('value'), ctx.state);
  final groupValue = stateKey != null
      ? (ctx.stateGet(stateKey)?.toString() ?? '')
      : resolveStringValue(ctx.prop('groupValue'), ctx.state);
  final activeColor = parseColor(ctx.prop('activeColor'));
  final inactiveColor = parseColor(ctx.prop('inactiveColor'));
  final isSelected = value == groupValue;

  return Theme(
    data: ThemeData(),
    child: GestureDetector(
      onTap: enabled && !isSelected
          ? () {
              if (stateKey != null && ctx.actionExecutor != null) {
                ctx.actionExecutor!.execute({
                  'type': 'setState',
                  'key': stateKey,
                  'value': value,
                });
              }
              ctx.fireAction('onChange', eventData: {'value': value});
            }
          : null,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (activeColor ?? const Color(0xFF2196F3))
                : (enabled
                      ? (inactiveColor ?? const Color(0xFF757575))
                      : const Color(0xFFBDBDBD)),
            width: 2,
          ),
        ),
        child: isSelected
            ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor ?? const Color(0xFF2196F3),
                  ),
                ),
              )
            : null,
      ),
    ),
  );
}

Widget _buildCheckbox(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final stateKey = ctx.prop<String>('stateKey');
  final tristate = ctx.propOr<bool>('tristate', false);
  final value = stateKey != null
      ? (ctx.stateGet(stateKey) as bool?)
      : ctx.prop<bool>('value');
  final label = resolveStringValue(ctx.prop('label'), ctx.state);
  final activeColor = parseColor(ctx.prop('activeColor'));
  final focusColor = parseColor(ctx.prop('focusColor'));
  final hoverColor = parseColor(ctx.prop('hoverColor'));

  void handleChange(bool? newValue) {
    final v = tristate ? newValue : (newValue ?? false);
    if (stateKey != null && ctx.actionExecutor != null) {
      ctx.actionExecutor!.execute({
        'type': 'setState',
        'key': stateKey,
        'value': v,
      });
    }
    ctx.fireAction('onChange', eventData: {'value': v});
  }

  // Same rationale as Switch: bare Checkbox when no label so it can sit in
  // an unbounded Row; CheckboxListTile only when a label is actually set.
  if (label.isEmpty) {
    return Checkbox(
      value: tristate ? value : (value ?? false),
      tristate: tristate,
      activeColor: activeColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      onChanged: enabled ? handleChange : null,
    );
  }

  return Theme(
    data: ThemeData(),
    child: CheckboxListTile(
      value: tristate ? value : (value ?? false),
      tristate: tristate,
      activeColor: activeColor,
      title: Text(label),
      onChanged: enabled ? handleChange : null,
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}

Widget _buildSwitch(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final stateKey = ctx.prop<String>('stateKey');
  final value = stateKey != null
      ? (ctx.stateGet(stateKey) as bool? ?? false)
      : ctx.propOr<bool>('value', false);
  final label = resolveStringValue(ctx.prop('label'), ctx.state);
  final activeColor = parseColor(ctx.prop('activeColor'));
  final inactiveColor = parseColor(ctx.prop('inactiveColor'));
  final focusColor = parseColor(ctx.prop('focusColor'));
  final hoverColor = parseColor(ctx.prop('hoverColor'));

  void handleChange(bool newValue) {
    if (stateKey != null && ctx.actionExecutor != null) {
      ctx.actionExecutor!.execute({
        'type': 'setState',
        'key': stateKey,
        'value': newValue,
      });
    }
    ctx.fireAction('onChange', eventData: {'value': newValue});
  }

  // Bare Switch when no label — lets callers place the toggle anywhere
  // (e.g. the `trailing` slot of a custom settings row). SwitchListTile
  // grabs the full width of its parent and explodes inside an unbounded
  // Row, which is a common layout and the one we hit most often.
  if (label.isEmpty) {
    return Switch(
      value: value,
      activeThumbColor: activeColor,
      inactiveTrackColor: inactiveColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      onChanged: enabled ? handleChange : null,
    );
  }

  return Theme(
    data: ThemeData(),
    child: SwitchListTile(
      value: value,
      activeThumbColor: activeColor,
      inactiveTrackColor: inactiveColor,
      title: Text(label),
      onChanged: enabled ? handleChange : null,
    ),
  );
}

Widget _buildSlider(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final stateKey = ctx.prop<String>('stateKey');
  final value = stateKey != null
      ? ((ctx.stateGet(stateKey) as num?)?.toDouble() ?? 0)
      : (ctx.prop<num>('value'))?.toDouble() ?? 0;
  final min = (ctx.prop<num>('min'))?.toDouble() ?? 0;
  final max = (ctx.prop<num>('max'))?.toDouble() ?? 1;
  final divisions = ctx.prop<int>('divisions');
  final activeColor = parseColor(ctx.prop('activeColor'));
  final inactiveColor = parseColor(ctx.prop('inactiveColor'));
  final thumbColor = parseColor(ctx.prop('thumbColor'));
  final trackHeight = (ctx.prop<num>('trackHeight'))?.toDouble();
  final label = ctx.prop<String>('label');

  Widget slider = Slider(
    value: value.clamp(min, max),
    min: min,
    max: max,
    divisions: divisions,
    activeColor: activeColor,
    inactiveColor: inactiveColor,
    thumbColor: thumbColor,
    label: label,
    onChanged: enabled
        ? (newValue) {
            if (stateKey != null && ctx.actionExecutor != null) {
              ctx.actionExecutor!.execute({
                'type': 'setState',
                'key': stateKey,
                'value': newValue,
              });
            }
            ctx.fireAction('onChange', eventData: {'value': newValue});
          }
        : null,
  );

  // Only override theme when trackHeight is explicitly set — Slider
  // inherits trackHeight from SliderThemeData, so wrapping unconditionally
  // would discard the ambient theme for every slider. Builder lets us read
  // the ambient theme without requiring a BuildContext on OrcaComponentContext.
  if (trackHeight != null) {
    slider = Builder(
      builder: (context) => SliderTheme(
        data: SliderTheme.of(context).copyWith(trackHeight: trackHeight),
        child: slider,
      ),
    );
  }

  return Theme(data: ThemeData(), child: slider);
}

/// Stateful wrapper for EditableText that preserves FocusNode and
/// TextEditingController across rebuilds, preventing focus loss on setState.
class _OrcaTextField extends StatefulWidget {
  final String value;
  final bool enabled;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final String? placeholder;
  final TextStyle? style;
  final TextInputType keyboardType;
  final bool autofocus;
  final bool readOnly;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputAction? textInputAction;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;

  const _OrcaTextField({
    super.key,
    required this.value,
    required this.enabled,
    required this.obscureText,
    required this.maxLines,
    this.maxLength,
    this.placeholder,
    this.style,
    required this.keyboardType,
    this.autofocus = false,
    this.readOnly = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textInputAction,
    this.decoration,
    this.onChanged,
  });

  @override
  State<_OrcaTextField> createState() => _OrcaTextFieldState();
}

class _OrcaTextFieldState extends State<_OrcaTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_OrcaTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text if it changed externally (not from user typing).
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.text = widget.value;
      // Restore cursor position if still valid.
      if (selection.start <= widget.value.length) {
        _controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        widget.style ?? const TextStyle(fontSize: 16, color: Color(0xFF000000));

    // When a decoration is set, use Material's TextField so we get the full
    // InputDecoration rendering (label, helper, error, border). Otherwise
    // stay on the lower-level EditableText path, which avoids pulling in the
    // Material ancestor when the author wants a bare field.
    if (widget.decoration != null) {
      return Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          textInputAction: widget.textInputAction,
          style: defaultStyle,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          // If the author set both placeholder and decoration.hintText,
          // prefer the decoration's — it lives on the same object as the
          // other decoration bits, so it's the clearer author intent.
          decoration:
              widget.decoration!.hintText == null &&
                  widget.placeholder != null &&
                  widget.placeholder!.isNotEmpty
              ? widget.decoration!.copyWith(hintText: widget.placeholder)
              : widget.decoration,
          onChanged: widget.onChanged,
        ),
      );
    }

    Widget field = EditableText(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: !widget.enabled || widget.readOnly,
      autofocus: widget.autofocus,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      textInputAction: widget.textInputAction,
      style: defaultStyle,
      cursorColor: const Color(0xFF2196F3),
      backgroundCursorColor: const Color(0xFFE0E0E0),
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.maxLength != null
          ? [LengthLimitingTextInputFormatter(widget.maxLength)]
          : null,
      onChanged: widget.onChanged,
    );

    // Show placeholder text when the field is empty.
    if (widget.placeholder != null && widget.placeholder!.isNotEmpty) {
      field = Stack(
        children: [
          field,
          if (_controller.text.isEmpty)
            IgnorePointer(
              child: Text(
                widget.placeholder!,
                style: defaultStyle.copyWith(color: const Color(0xFF9E9E9E)),
              ),
            ),
        ],
      );
    }

    return Material(type: MaterialType.transparency, child: field);
  }
}

TextInputType _parseInputType(String? value) {
  return switch (value) {
    'number' => TextInputType.number,
    'email' => TextInputType.emailAddress,
    'phone' => TextInputType.phone,
    'url' => TextInputType.url,
    'multiline' => TextInputType.multiline,
    _ => TextInputType.text,
  };
}

TextInputAction? _parseTextInputAction(String? value) {
  return switch (value) {
    'done' => TextInputAction.done,
    'go' => TextInputAction.go,
    'newline' => TextInputAction.newline,
    'next' => TextInputAction.next,
    'previous' => TextInputAction.previous,
    'search' => TextInputAction.search,
    'send' => TextInputAction.send,
    'join' => TextInputAction.join,
    'route' => TextInputAction.route,
    'emergencyCall' => TextInputAction.emergencyCall,
    'continueAction' => TextInputAction.continueAction,
    'unspecified' => TextInputAction.unspecified,
    _ => null,
  };
}
