import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 渲染宿主支持的插件配置协议，不依赖具体插件。
class PluginSettingsForm extends StatefulWidget {
  const PluginSettingsForm({
    super.key,
    required this.schema,
    required this.values,
    required this.enabled,
    this.fieldErrors = const {},
    this.onEdited,
  });

  final Map<String, dynamic> schema;
  final Map<String, dynamic> values;
  final bool enabled;
  final Map<String, String> fieldErrors;
  final VoidCallback? onEdited;

  @override
  State<PluginSettingsForm> createState() => _PluginSettingsFormState();
}

class _PluginSettingsFormState extends State<PluginSettingsForm> {
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _buildObject(widget.schema, widget.values, '');

  Widget _buildObject(
    Map<String, dynamic> schema,
    Map<String, dynamic> values,
    String path,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry
            in (schema['properties'] as Map<String, dynamic>).entries)
          if ((entry.value as Map)['x-hidden'] != true)
            Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.lg),
              child: _buildField(
                entry.key,
                entry.value,
                values,
                path.isEmpty ? entry.key : '$path.${entry.key}',
                (schema['required'] as List? ?? []).contains(entry.key),
              ),
            ),
      ],
    );
  }

  Widget _description(Widget child, String? description) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      if (description != null) ...[
        SizedBox(height: context.appSpacing.xs),
        Text(
          description,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    ],
  );

  Widget _buildField(
    String name,
    Map<String, dynamic> field,
    Map<String, dynamic> values,
    String path,
    bool required,
  ) {
    final title = '${field['title'] ?? name}${required ? ' *' : ''}';
    final description = field['description'] as String?;
    final value = values[name];
    final nullable = field['nullable'] == true;
    final type = field['type'];
    final key = Key('plugin-setting-$path');
    String? error() => widget.fieldErrors[path];
    void change(dynamic next) {
      setState(() => values[name] = next);
      widget.onEdited?.call();
    }

    if (type == 'object') {
      // 已保存的对象类型错误时允许用户从字段重新填写。
      final nested = value is Map<String, dynamic>
          ? value
          : <String, dynamic>{};
      values[name] = nested;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _description(
            Text(
              title,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
              ),
            ),
            description,
          ),
          SizedBox(height: context.appSpacing.md),
          _buildObject(field, nested, path),
        ],
      );
    }
    final choices = field['enum'] as List?;
    if (choices != null || (type == 'boolean' && nullable)) {
      final options = <dynamic>[
        if (nullable) null,
        ...?choices,
        if (choices == null) ...[false, true],
      ];
      final index = options.indexOf(value);
      return _description(
        AppSelectField<int>(
          key: key,
          label: title,
          value: index < 0 ? null : index,
          items: [
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  options[i] == null
                      ? '未设置'
                      : type == 'boolean'
                      ? (options[i] == true ? '开启' : '关闭')
                      : options[i].toString(),
                ),
              ),
          ],
          validator: (_) =>
              error() ?? (options.contains(values[name]) ? null : '请选择一项'),
          onChanged: widget.enabled
              ? (i) {
                  if (i != null) change(options[i]);
                }
              : null,
        ),
        description,
      );
    }
    if (type == 'boolean') {
      return FormField<bool>(
        validator: (_) => error() ?? (values[name] is bool ? null : '请选择开关状态'),
        builder: (state) => _description(
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: resolveAppTextStyle(context, size: AppTextSize.s14),
                ),
              ),
              Semantics(
                label: title,
                child: AppSwitch(
                  key: key,
                  value: values[name] == true,
                  onChanged: widget.enabled ? change : null,
                ),
              ),
            ],
          ),
          state.errorText ?? description,
        ),
      );
    }
    final number = type == 'integer' || type == 'number';
    final list = type == 'array';
    final controller = _controllers.putIfAbsent(
      path,
      () => TextEditingController(
        text: list && value is List
            ? value.join('\n')
            : value?.toString() ?? '',
      ),
    );
    String? validate(String? text) {
      if (error() != null) return error();
      final input = text ?? '';
      dynamic parsed;
      if (input.isEmpty && nullable) {
        parsed = null;
      } else if (number) {
        parsed = type == 'integer' ? int.tryParse(input) : num.tryParse(input);
        if (parsed == null || !(parsed as num).isFinite) {
          return type == 'integer' ? '请输入整数' : '请输入数字';
        }
        final minimum = field['minimum'] as num?;
        final maximum = field['maximum'] as num?;
        final exclusiveMin = field['exclusiveMinimum'] as num?;
        final exclusiveMax = field['exclusiveMaximum'] as num?;
        if (minimum != null && parsed < minimum) return '不能小于 $minimum';
        if (maximum != null && parsed > maximum) return '不能大于 $maximum';
        if (exclusiveMin != null && parsed <= exclusiveMin) {
          return '必须大于 $exclusiveMin';
        }
        if (exclusiveMax != null && parsed >= exclusiveMax) {
          return '必须小于 $exclusiveMax';
        }
      } else if (list) {
        parsed = input
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      } else {
        parsed = input;
        if (required && input.isEmpty) return '请填写$title';
        final min = field['minLength'] as int?;
        final max = field['maxLength'] as int?;
        if (min != null && input.runes.length < min) return '至少输入 $min 个字符';
        if (max != null && input.runes.length > max) return '最多输入 $max 个字符';
      }
      values[name] = parsed;
      return null;
    }

    final bounds = [
      if (field['minimum'] != null) '最小 ${field['minimum']}',
      if (field['exclusiveMinimum'] != null) '大于 ${field['exclusiveMinimum']}',
      if (field['maximum'] != null) '最大 ${field['maximum']}',
      if (field['exclusiveMaximum'] != null) '小于 ${field['exclusiveMaximum']}',
    ].join('，');
    final helper = [
      if (description != null) description,
      if (list) '每行一项',
      if (number && bounds.isNotEmpty) bounds,
      if (nullable && description == null) '留空表示未设置',
    ].join('；');
    if (field['format'] == 'password' || field['writeOnly'] == true) {
      return AppPasswordField(
        fieldKey: key,
        controller: controller,
        label: title,
        helperText: helper.isEmpty ? null : helper,
        enabled: widget.enabled,
        validator: validate,
        onChanged: (_) => widget.onEdited?.call(),
      );
    }
    final multiline = list || field['x-multiline'] == true;
    return AppTextField(
      fieldKey: key,
      controller: controller,
      label: title,
      helperText: helper.isEmpty ? null : helper,
      enabled: widget.enabled,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 5 : 1,
      keyboardType: number
          ? TextInputType.numberWithOptions(
              decimal: type == 'number',
              signed: true,
            )
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      validator: validate,
      onChanged: (_) => widget.onEdited?.call(),
    );
  }
}
