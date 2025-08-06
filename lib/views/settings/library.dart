import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart';

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
  showAdaptiveDialog(
    context: context,
    builder: (context) {
      var categoryname = category.name;
      final controller = TextEditingController(text: categoryname);
      return Dialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Update Category'),
            DionTextbox(
              controller: controller,
              onChanged: (value) => categoryname = value,
            ),
            ElevatedButton(
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
    builder: (context) => Dialog(
      child: LoadingBuilder(
        future: locate<Database>().getCategories(),
        builder: (context, value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Category'),
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

void showAddCategoryDialog(BuildContext context) {
  final db = locate<Database>();
  showAdaptiveDialog(
    context: context,
    builder: (context) {
      var categoryname = '';
      return Dialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Category'),
            DionTextbox(onChanged: (value) => categoryname = value),
            ElevatedButton(
              onPressed: () async {
                if (categoryname.isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                await db.updateCategory(Category.construct(categoryname));
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

class CategorySettings extends StatelessWidget {
  const CategorySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final db = locate<Database>();
    return ListenableBuilder(
      listenable: db,
      builder: (context, child) => LoadingBuilder(
        future: db.getCategories(),
        builder: (context, categories) => SettingTitle(
          title: 'Categories',
          children: [
            for (final category in categories)
              Row(
                children: [
                  DionTextbutton(
                    onPressed: () async {
                      showUpdateDialog(context, category);
                    },
                    child: Text(category.name),
                  ),
                  const Spacer(),
                  DionTextbutton(
                    onPressed: () async {
                      await db.removeCategory(category);
                    },
                    child: const Icon(Icons.delete),
                  ),
                ],
              ).paddingAll(2.5),
            30.0.heightBox,
            DionTextbutton(
              child: const Text('Add Category'),
              onPressed: () {
                showAddCategoryDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
