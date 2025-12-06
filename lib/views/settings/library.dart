import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart'
    show
        Divider,
        Icons,
        ListTile,
        ReorderableListView,
        showAdaptiveDialog,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class LibrarySettings extends StatelessWidget {
  const LibrarySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        children: [
          const CategorySettings(),
          SettingToggle(
            title: 'Show All Tab',
            setting: settings.library.showAllTab,
          ),
          SettingToggle(
            title: 'Show None Tab',
            setting: settings.library.showNoneTab,
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
    }, db).disposedBy(scope);
  }

  @override
  Widget build(BuildContext context) {
    final categories = this.categories;
    if (categories == null) {
      return const DionProgressBar();
    }
    return SettingTitle(
      title: 'Categories',
      children: [
        ReorderableListView(
          shrinkWrap: true,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final cat = categories.removeAt(oldIndex);
              categories.insert(min(newIndex, categories.length - 1), cat);
              int i = 0;
              this.categories = categories
                  .map((e) => e.copyWith(index: i++))
                  .toList();
            });
            locate<Database>().updateCategories(this.categories!);
          },
          children: [
            for (final category in categories)
              ListTile(
                key: ValueKey(category),
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.index.toString()),
                    8.0.widthBox,
                    DionIconbutton(
                      onPressed: () {
                        showUpdateDialog(context, category);
                      },
                      icon: const Icon(Icons.edit),
                    ),
                    DionIconbutton(
                      onPressed: () async {
                        await locate<Database>().removeCategory(category);
                      },
                      icon: const Icon(Icons.delete),
                    ),
                    14.0.widthBox,
                  ],
                ),
              ),
          ],
        ),
        const Divider(),
        DionTextbutton(
          child: const Text('Add Category'),
          onPressed: () {
            showAddCategoryDialog(context, categories.length);
          },
        ),
      ],
    );
  }
}
