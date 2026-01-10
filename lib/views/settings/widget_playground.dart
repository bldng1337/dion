import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/buttons/togglebutton.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/popupmenu.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:dionysos/widgets/selection.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/slider.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:flutter/material.dart';

class WidgetPlayground extends StatelessWidget {
  const WidgetPlayground({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Widget Playground'),
      child: ListView(
        children: [
          SettingTitle(
            title: 'Buttons',
            children: [
              const Text('Text Buttons').paddingOnly(bottom: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DionTextbutton(
                    onPressed: () {},
                    child: const Text('Filled'),
                  ),
                  DionTextbutton(
                    type: ButtonType.ghost,
                    onPressed: () {},
                    child: const Text('Ghost'),
                  ),
                  DionTextbutton(
                    type: ButtonType.elevated,
                    onPressed: () {},
                    child: const Text('Elevated'),
                  ),
                  const DionTextbutton(
                    child: Text('Disabled'),
                  ),
                  DionTextbutton(
                    onPressed: () => Future.delayed(const Duration(seconds: 2)),
                    child: const Text('Loading'),
                  ),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Icon Buttons').paddingOnly(bottom: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DionIconbutton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite),
                  ),
                  DionIconbutton(
                    onPressed: () {},
                    icon: const Icon(Icons.bookmark),
                    tooltip: 'Bookmark',
                  ),
                  const DionIconbutton(
                    icon: Icon(Icons.delete),
                  ),
                  DionIconbutton(
                    onPressed: () => Future.delayed(const Duration(seconds: 2)),
                    icon: const Icon(Icons.cloud_upload),
                  ),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Toggle Button').paddingOnly(bottom: 8),
              Row(
                children: [
                  const Togglebutton(
                    selected: true,
                  ).paddingOnly(right: 8),
                  const Togglebutton(selected: false),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Action Button (FAB)').paddingOnly(bottom: 8),
              ActionButton(
                onPressed: () => Future.delayed(const Duration(seconds: 2)),
                child: const Icon(Icons.add),
              ).paddingOnly(bottom: 16),
              const ActionButton(
                child: Icon(Icons.add),
              ).paddingOnly(bottom: 16),
            ],
          ),
          SettingTitle(
            title: 'Inputs & Controls',
            children: [
              const Text('Searchbar').paddingOnly(bottom: 8),
              DionSearchbar(
                hintText: 'Search...',
                onChanged: (value) {},
              ).paddingOnly(bottom: 16),
              const Text('Dropdown').paddingOnly(bottom: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DionDropdown<String>(
                    items: const [
                      DionDropdownItem(value: 'opt1', label: 'Option 1'),
                      DionDropdownItem(value: 'opt2', label: 'Option 2'),
                      DionDropdownItem(value: 'opt3', label: 'Option 3'),
                    ],
                    value: 'opt1',
                    onChanged: (value) {},
                  ),
                  DionDropdown<String>(
                    items: const [
                      DionDropdownItemWidget(
                        value: 'opt1',
                        labelWidget: Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Starred Option'),
                          ],
                        ),
                        label: 'Starred Option',
                        selectedItemWidget: Row(
                          children: [
                            Icon(Icons.star, color: Colors.red),
                            SizedBox(width: 8),
                            Text('This is a very long selected option'),
                          ],
                        ),
                      ),
                      DionDropdownItem(value: 'opt2', label: 'Option 2'),
                      DionDropdownItem(value: 'opt3', label: 'Option 3'),
                    ],
                    value: 'opt1',
                    onChanged: (value) {},
                  ),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Slider').paddingOnly(bottom: 8),
              DionSlider<int>(
                value: 50,
                min: 0,
                max: 100,
                onChanged: (value) {},
              ).paddingOnly(bottom: 8),
              DionSlider<double>(
                value: 0.5,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {},
              ).paddingOnly(bottom: 16),
              const Text('Selection Area').paddingOnly(bottom: 8),
              const Selection(
                child: Text(
                  'This text can be selected and copied. '
                  'Try selecting this text with your mouse or touch input.',
                ),
              ).paddingOnly(bottom: 16),
            ],
          ),
          SettingTitle(
            title: 'Containers & Layout',
            children: [
              const Text('Custom Containers').paddingOnly(bottom: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DionContainer(
                    type: ContainerType.filled,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Filled'),
                    ),
                  ),
                  DionContainer(
                    type: ContainerType.ghost,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Ghost'),
                    ),
                  ),
                  DionContainer(
                    type: ContainerType.outlined,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Outlined'),
                    ),
                  ),
                  DionContainer(
                    emphasized: true,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Emphasized'),
                    ),
                  ),
                ],
              ).paddingOnly(bottom: 16),
              const Text('List Tiles').paddingOnly(bottom: 8),
              Column(
                children: [
                  DionListTile(title: const Text('Title only'), onTap: () {}),
                  DionListTile(
                    title: const Text('Title and subtitle'),
                    subtitle: const Text('This is a subtitle'),
                    onTap: () {},
                  ),
                  DionListTile(
                    leading: const Icon(Icons.folder),
                    title: const Text('With leading icon'),
                    subtitle: const Text('Folder content'),
                    onTap: () {},
                  ),
                  DionListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('With trailing widget'),
                    subtitle: const Text('Settings menu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Badge').paddingOnly(bottom: 8),
              Wrap(
                spacing: 8,
                children: [
                  DionBadge(
                    color: Colors.red,
                    child: Text(
                      '5',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.notifications),
                  DionBadge(
                    color: Colors.blue,
                    child: Text(
                      '99+',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.mail),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Foldable Text').paddingOnly(bottom: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Foldabletext(
                  'This is a long text that should be foldable. '
                  'It contains multiple lines of text that will be truncated '
                  'when not expanded. Click on this text to expand or collapse '
                  'it. This helps in managing screen space when displaying '
                  'long content. The text will show an indicator when it can '
                  'be expanded.${getText(100)}',
                  // maxLines: 1,
                ),
              ).paddingOnly(bottom: 16),
            ],
          ),
          SettingTitle(
            title: 'Feedback & Status',
            children: [
              const Text('Progress Indicators').paddingOnly(bottom: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const DionProgressBar(
                    
                  ).paddingOnly(right: 16),
                  const DionProgressBar(
                    value: 0.5,
                  ).paddingOnly(right: 16),
                  const DionProgressBar(type: DionProgressType.linear),
                ],
              ).paddingOnly(bottom: 16),
              const Text('Error Display').paddingOnly(bottom: 8),
              SizedBox(
                width: 300,
                height: 300,
                child: ErrorDisplay(
                  e: Exception('Sample error message'),
                  s: StackTrace.current,
                  message: 'Something went wrong',
                  actions: [
                    ErrorAction(
                      label: 'Retry',
                      onTap: () => Future.delayed(10.0.seconds),
                    ),
                    const ErrorAction(label: 'Dismiss'),
                  ],
                ),
              ).paddingOnly(bottom: 16),
              SizedBox(
                width: 150,
                height: 150,
                child: ErrorDisplay(
                  e: Exception('Different error type'),
                  s: StackTrace.current,
                  message: 'Custom error',
                ),
              ).paddingOnly(bottom: 16),
              SizedBox(
                width: 50,
                height: 50,
                child: ErrorDisplay(
                  e: Exception('Different error type'),
                  s: StackTrace.current,
                  message: 'Custom error',
                ),
              ).paddingOnly(bottom: 16),
            ],
          ),
          SettingTitle(
            title: 'Navigation',
            children: [
              const Text('Tab Bar').paddingOnly(bottom: 8),
              const SizedBox(
                height: 200,
                child: DionTabBar(
                  tabs: [
                    DionTab(
                      tab: Text('Tab 1'),
                      child: Center(child: Text('Content 1')),
                    ),
                    DionTab(
                      tab: Text('Tab 2'),
                      child: Center(child: Text('Content 2')),
                    ),
                    DionTab(
                      tab: Text('Tab 3'),
                      child: Center(child: Text('Content 3')),
                    ),
                  ],
                ),
              ).paddingOnly(bottom: 16),
              const SizedBox(
                height: 200,
                child: DionTabBar(
                  scrollable: true,
                  tabs: [
                    DionTab(
                      tab: Text('Tab 1'),
                      child: Center(child: Text('Content 1')),
                    ),
                    DionTab(
                      tab: Text('Tab 2'),
                      child: Center(child: Text('Content 2')),
                    ),
                    DionTab(
                      tab: Text('Tab 3'),
                      child: Center(child: Text('Content 3')),
                    ),
                  ],
                ),
              ).paddingOnly(bottom: 16),
              // SizedBox( TODO: Fix trailing tab bar
              //   height: 200,
              //   child: DionTabBar(
              //     trailing: const Icon(Icons.abc),
              //     tabs: [
              //       DionTab(
              //         tab: const Text('Tab 1'),
              //         child: const Center(child: Text('Content 1')),
              //       ),
              //       DionTab(
              //         tab: const Text('Tab 2'),
              //         child: const Center(child: Text('Content 2')),
              //       ),
              //       DionTab(
              //         tab: const Text('Tab 3'),
              //         child: const Center(child: Text('Content 3')),
              //       ),
              //     ],
              //   ),
              // ).paddingOnly(bottom: 16),
              const SizedBox(
                height: 200,
                child: DionTabBar(
                  trailing: Icon(Icons.abc),
                  scrollable: true,
                  tabs: [
                    DionTab(
                      tab: Text('Tab 1'),
                      child: Center(child: Text('Content 1')),
                    ),
                    DionTab(
                      tab: Text('Tab 2'),
                      child: Center(child: Text('Content 2')),
                    ),
                    DionTab(
                      tab: Text('Tab 3'),
                      child: Center(child: Text('Content 3')),
                    ),
                  ],
                ),
              ).paddingOnly(bottom: 16),
            ],
          ),
          SettingTitle(
            title: 'Overlays',
            children: [
              const Text('Popup Menu').paddingOnly(bottom: 8),
              DionPopupMenu(
                items: [
                  DionPopupMenuItem(
                    label: const Text('Action 1'),
                    onTap: () {},
                  ),
                  DionPopupMenuItem(
                    label: const Text('Action 2'),
                    onTap: () {},
                  ),
                  DionPopupMenuItem(
                    label: const Text('Action 3'),
                    onTap: () {},
                  ),
                ],
                child: const DionContainer(
                  width: 200,
                  height: 80,
                  type: ContainerType.ghost,
                  child: Text('Show Popup Menu'),
                ),
              ).paddingOnly(bottom: 16),
              const Text('Context Menu').paddingOnly(bottom: 8),
              ContextMenu(
                contextItems: [
                  ContextMenuItem(label: 'Copy', onTap: () async {}),
                  ContextMenuItem(label: 'Paste', onTap: () async {}),
                ],
                child: const DionContainer(
                  width: 200,
                  height: 80,
                  type: ContainerType.ghost,
                  child: Text('Right-click me'),
                ),
              ).paddingOnly(bottom: 16),
              const Text('Dialogs').paddingOnly(bottom: 8),
              Row(
                children: [
                  DionTextbutton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const DionDialog(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Custom Dialog'),
                                SizedBox(height: 16),
                                Text('Dialog content goes here'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Show Dialog'),
                  ).paddingOnly(right: 8),
                  DionTextbutton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => DionAlertDialog(
                          title: const Text('Alert'),
                          content: const Text('This is an alert dialog'),
                          actions: [
                            DionTextbutton(
                              type: ButtonType.ghost,
                              onPressed: () => context.pop(),
                              child: const Text('Cancel'),
                            ),
                            DionTextbutton(
                              onPressed: () => context.pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Alert'),
                  ),
                ],
              ).paddingOnly(bottom: 16),
            ],
          ),
          SettingTitle(
            title: 'Loadable Pattern',
            children: [
              const Text('Loadable Button').paddingOnly(bottom: 8),
              // Note the DionTextbutton already uses Loadable internally so for simple loading flows just return a future from onPressed or make the callback async.
              const Text('Custom Loading State').paddingOnly(bottom: 8),
              Loadable(
                loading: const Center(
                  child: Column(
                    children: [
                      Text('Some Custom Loading State...'),
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading...'),
                    ],
                  ),
                ),
                builder: (context, child, setFuture) => Column(
                  children: [
                    const SizedBox(height: 42),
                    DionTextbutton(
                      onPressed: () {
                        setFuture(Future.delayed(const Duration(seconds: 2)));
                      },
                      child: child,
                    ),
                  ],
                ),
              ).paddingOnly(bottom: 16),
            ],
          ),
        ],
      ),
    );
  }
}
