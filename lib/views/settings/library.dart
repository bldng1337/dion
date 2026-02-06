import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart'
    show Colors, Icons, InkWell, Material, showAdaptiveDialog, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class LibrarySettings extends StatelessWidget {
  const LibrarySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          const CategorySettings(),

          SettingTitle(
            title: 'Display',
            subtitle: 'Library tab options',
            children: [
              SettingToggle(
                title: 'Show All Tab',
                description: 'Display tab showing all entries',
                setting: settings.library.showAllTab,
              ),
              SettingToggle(
                title: 'Show None Tab',
                description: 'Display tab for uncategorized entries',
                setting: settings.library.showNoneTab,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showUpdateDialog(BuildContext context, Category category) {
  final db = locate<Database>();
  showDialog(
    context: context,
    builder: (context) {
      var categoryname = category.name;
      final controller = TextEditingController(text: categoryname);
      return DionDialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Update Category'),
            DionTextbox(
              controller: controller,
              onChanged: (value) => categoryname = value,
            ),
            DionTextbutton(
              onPressed: () async {
                if (categoryname.isEmpty) {
                  await db.removeCategory(category);
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pop(context);
                  return;
                }
                if (categoryname == category.name) {
                  Navigator.pop(context);
                  return;
                }
                await db.updateCategory(category.copyWith(name: categoryname));
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ).paddingAll(15),
      );
    },
  );
}

void showEditCategoriesDialog(BuildContext context, EntrySaved entry) {
  showAdaptiveDialog(
    context: context,
    builder: (context) => DionDialog(
      child: LoadingBuilder(
        future: locate<Database>().getCategories(),
        builder: (context, value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Categories'),
            DionMultiDropdown(
              defaultItem: const Text('Choose a category'),
              items: value
                  .map(
                    (e) => entry.categories.contains(e)
                        ? MultiDropdownItem.active(value: e, label: e.name)
                        : MultiDropdownItem(value: e, label: e.name),
                  )
                  .toList(),
              onSelectionChange: (selection) async {
                entry.categories = selection;
              },
            ).paddingAll(10),
            DionTextbutton(
              child: const Text('Save'),
              onPressed: () async {
                try {
                  await entry.save();
                } catch (e) {
                  logger.e('Failed to save entry', error: e);
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
              },
            ),
          ],
        ).paddingAll(15),
      ),
    ),
  );
}

void showAddCategoryDialog(BuildContext context, int index) {
  final db = locate<Database>();
  showAdaptiveDialog(
    context: context,
    builder: (context) {
      var categoryname = '';
      return DionDialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Category'),
            DionTextbox(onChanged: (value) => categoryname = value),
            DionTextbutton(
              onPressed: () async {
                if (categoryname.isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                await db.updateCategory(
                  Category.construct(categoryname, index),
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ).paddingAll(15),
      );
    },
  );
}

class CategorySettings extends StatefulWidget {
  const CategorySettings({super.key});

  @override
  State<CategorySettings> createState() => _CategorySettingsState();
}

class _CategorySettingsState extends State<CategorySettings>
    with StateDisposeScopeMixin {
  List<Category>? categories;

  @override
  void initState() {
    super.initState();
    final db = locate<Database>();
    Observer(() async {
      if (mounted) {
        final categories = await db.getCategories();
        categories.sort((a, b) => a.index.compareTo(b.index));
        setState(() {
          this.categories = categories;
        });
      }
    }, db.getListenable(DBEvent.categoryUpdated)).disposedBy(scope);
  }

  @override
  Widget build(BuildContext context) {
    final categories = this.categories;
    if (categories == null) {
      return const Padding(
        padding: EdgeInsets.all(DionSpacing.xl),
        child: Center(child: DionProgressBar()),
      );
    }

    return SettingTitle(
      title: 'Categories',
      subtitle: 'Organize your library',
      children: [
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(DionSpacing.lg),
            child: Center(
              child: Text(
                'No categories yet',
                style: DionTypography.bodySmall(context.textTertiary),
              ),
            ),
          ),
        ...categories.map(
          (category) => _CategoryTile(
            category: category,
            onEdit: () => showUpdateDialog(context, category),
            onDelete: () async {
              await locate<Database>().removeCategory(category);
            },
          ),
        ),
        _AddCategoryButton(
          onTap: () => showAddCategoryDialog(context, categories.length),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 18, color: context.textTertiary),
          const SizedBox(width: DionSpacing.md),
          Expanded(
            child: Text(
              category.name,
              style: DionTypography.titleSmall(context.textPrimary),
            ),
          ),
          DionIconbutton(
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: context.textSecondary,
            ),
          ),
          DionIconbutton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, size: 18, color: DionColors.error),
          ),
        ],
      ),
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCategoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: DionColors.primary),
              const SizedBox(width: DionSpacing.md),
              Text(
                'Add Category',
                style: DionTypography.titleSmall(DionColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
