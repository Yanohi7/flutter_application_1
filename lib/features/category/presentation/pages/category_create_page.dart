// Create or edit a category with name validation, parent selection and unsaved-change protection

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/features/category/presentation/category_display_name.dart';
import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_ui.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entry_category.dart';
import '../cubit/category_cubit.dart';
import '../cubit/category_state.dart';
import '../widgets/category_picker.dart';

Future<EntryCategory?> showCategoryEditor(
  BuildContext context, {
  EntryCategory? category,
  int? initialParentId,
}) => showAppDialog<EntryCategory>(
  context: context,
  barrierDismissible: false,
  builder: (_) => BlocProvider.value(
    value: context.read<CategoryCubit>(),
    child: CategoryCreatePage(
      category: category,
      initialParentId: initialParentId,
    ),
  ),
);

class CategoryCreatePage extends StatefulWidget {
  final EntryCategory? category;
  final int? initialParentId;

  const CategoryCreatePage({super.key, this.category, this.initialParentId});

  @override
  State<CategoryCreatePage> createState() => _CategoryCreatePageState();
}

class _CategoryCreatePageState extends State<CategoryCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();

  int? _parentId;

  bool _submitting = false;

  String? _saveError;

  bool _allowPop = false;
  bool _askingToLeave = false;

  // Compare the draft with its starting values before allowing navigation away
  bool get _isDirty =>
      _name.text != (widget.category?.name ?? '') ||
      _parentId != (widget.category?.parentId ?? widget.initialParentId);

  @override
  void initState() {
    super.initState();
    _name.text = widget.category?.name ?? '';
    _parentId = widget.category?.parentId ?? widget.initialParentId;
  }

  Future<void> _confirmLeave() async {
    if (_submitting || _askingToLeave) return;
    _askingToLeave = true;
    final discard = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(AppLocalizations.of(context)!.discardUnsavedChanges),
        content: Text(
          AppLocalizations.of(context)!.yourCategoryChangesWillNotBeSaved,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.discard),
          ),
        ],
      ),
    );
    _askingToLeave = false;
    if (!mounted || discard != true) return;
    setState(() => _allowPop = true);
    // Wait for PopScope to receive the updated exit permission before popping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // Validate the draft, choose creation or editing and return success to the caller
  Future<void> _save() async {
    if (_submitting) return;

    final cubit = context.read<CategoryCubit>();

    if (cubit.state.isSaving || cubit.state.status != CategoryStatus.success) {
      return;
    }

    if (_formKey.currentState?.validate() != true) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _saveError = null;
    });

    final original = widget.category;
    int? destinationId = original?.id;
    final bool saved;
    if (original == null) {
      final created = await cubit.createCategory(
        name: _name.text,
        parentId: _parentId,
      );
      destinationId = created?.id;
      saved = created != null;
    } else {
      saved = await cubit.updateCategory(
        id: original.id,
        name: _name.text,
        parentId: _parentId,
      );
    }

    if (!mounted) return;

    if (!saved) {
      setState(() {
        _submitting = false;
        _saveError =
            cubit.state.errorMessage ??
            AppLocalizations.of(context)!.failedToSaveCategory;
      });
      return;
    }

    // Return the saved category without changing navigation behind the editor.
    final result =
        cubit.state.categories
            .where((item) => item.id == destinationId)
            .firstOrNull ??
        EntryCategory(
          id: destinationId!,
          name: _name.text.trim(),
          parentId: _parentId,
          isDefault: original?.isDefault ?? false,
        );

    setState(() {
      _submitting = false;
      _allowPop = true;
    });

    // Wait for PopScope to receive the updated exit permission before popping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  Future<void> _chooseParent() async {
    if (widget.category?.isDefault == true) return;
    final state = context.read<CategoryCubit>().state;
    if (_submitting ||
        state.isSaving ||
        state.status != CategoryStatus.success) {
      return;
    }
    FocusScope.of(context).unfocus();
    // Exclude the edited category and its entire subtree
    final excluded = <int>{};
    final original = widget.category;
    if (original != null) {
      final pending = <int>[original.id];
      while (pending.isNotEmpty) {
        final id = pending.removeLast();
        if (!excluded.add(id)) continue;
        pending.addAll(
          state.categories
              .where((category) => category.parentId == id)
              .map((category) => category.id),
        );
      }
    }
    final selection = await showCategoryPicker(
      context: context,
      categories: state.categories
          .where((category) => !excluded.contains(category.id))
          .toList(),
      selectedId: _parentId,
      allowTopLevel: true,
      title: AppLocalizations.of(context)!.parentCategory,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _parentId = selection.id;
      _saveError = null;
    });
  }

  void _close() {
    if (_submitting) return;
    if (_isDirty) {
      _confirmLeave();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting && (_allowPop || !_isDirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmLeave();
    },
    child: BlocBuilder<CategoryCubit, CategoryState>(
      builder: (context, state) {
        final busy = _submitting || state.isSaving;
        final byId = {
          for (final category in state.categories) category.id: category,
        };
        return AppDialog(
          title: widget.category == null
              ? AppLocalizations.of(context)!.createNewCategory
              : AppLocalizations.of(context)!.editCategory,
          onClose: busy ? null : _close,
          child:
              state.status == CategoryStatus.initial ||
                  state.status == CategoryStatus.loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : state.status == CategoryStatus.failure
              ? OutlinedButton.icon(
                  onPressed: context.read<CategoryCubit>().loadCategories,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.tryAgain),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Name'),
                      TextFormField(
                        controller: _name,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.categoryName,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppLocalizations.of(context)!.enterTheCategoryName
                            : null,
                        onChanged: (_) => setState(() => _saveError = null),
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 16),
                      FieldLabel(AppLocalizations.of(context)!.parentCategory),
                      InkWell(
                        onTap: busy || widget.category?.isDefault == true
                            ? null
                            : _chooseParent,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            enabled:
                                !busy && widget.category?.isDefault != true,
                            helperText: widget.category?.isDefault == true
                                ? AppLocalizations.of(context)!
                                      .theDefaultCategoryStaysAtTheTopLevel
                                : null,
                            helperMaxLines: 4,
                          ),
                          child: Text(
                            _parentId == null
                                ? AppLocalizations.of(context)!.noneTopLevel
                                : AppLocalizations.of(context)!
                                      .categoryDisplayName(
                                        byId[_parentId]?.name ??
                                            AppLocalizations.of(context)!
                                                .chooseCategory,
                                      ),
                          ),
                        ),
                      ),
                      if (_saveError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: busy ? null : _close,
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          FilledButton(
                            onPressed: busy ? null : _save,
                            child: Text(
                              busy
                                  ? AppLocalizations.of(context)!.saving
                                  : AppLocalizations.of(context)!.saveCategory,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    ),
  );
}
