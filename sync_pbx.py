#!/usr/bin/env python3
"""Rebuild Xcode project.pbxproj to include all Swift/resources under the app folder."""
import os
import re
import sys
import uuid
from collections import defaultdict


def uid():
    return uuid.uuid4().hex[:24].upper()


def main(root):
    root = os.path.abspath(root)
    name = os.path.basename(root.rstrip("/"))
    pbx_path = os.path.join(root, f"{name}.xcodeproj", "project.pbxproj")
    app_dir = os.path.join(root, name)

    with open(pbx_path) as f:
        pbx = f.read()

    m = re.search(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", pbx)
    bundle = m.group(1).strip() if m else f"com.app.{name}"
    m2 = re.search(r"\bINFOPLIST_FILE = ([^;]+);", pbx)
    infoplist = m2.group(1).strip() if m2 else f"{name}/App/Info.plist"
    if infoplist in ("NO", "YES"):
        infoplist = f"{name}/App/Info.plist"

    swift_files = []
    md_files = []
    image_files = []
    assets_rel = None
    info_rel = None

    for dirpath, dirnames, filenames in os.walk(app_dir):
        if os.path.basename(dirpath) == "Assets.xcassets":
            assets_rel = os.path.relpath(dirpath, app_dir)
            dirnames[:] = []
            continue
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, app_dir)
            if fn.endswith(".swift"):
                swift_files.append(rel)
            elif fn.endswith(".md"):
                md_files.append(rel)
            elif fn.lower().endswith((".png", ".jpg", ".jpeg")):
                image_files.append(rel)
            elif fn == "Info.plist":
                info_rel = rel

    product_ref = uid()
    project_id = uid()
    target_id = uid()
    sources_phase = uid()
    resources_phase = uid()
    frameworks_phase = uid()
    main_group = uid()
    products_group = uid()
    src_group = uid()
    config_list_proj = uid()
    config_list_tgt = uid()
    debug_proj = uid()
    release_proj = uid()
    debug_tgt = uid()
    release_tgt = uid()

    build_file_section = []
    file_ref_section = []
    source_phase_files = []
    resource_phase_files = []
    folders = defaultdict(list)

    file_ref_section.append(
        f'\t\t{product_ref} /* {name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {name}.app; sourceTree = BUILT_PRODUCTS_DIR; }};'
    )

    def add_file(rel, kind):
        base = os.path.basename(rel)
        fr = uid()
        folder = os.path.dirname(rel)
        if kind == "swift":
            file_ref_section.append(
                f'\t\t{fr} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {base}; sourceTree = "<group>"; }};'
            )
            bf = uid()
            build_file_section.append(
                f'\t\t{bf} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {base} */; }};'
            )
            source_phase_files.append(f"\t\t\t\t{bf} /* {base} in Sources */,")
        elif kind == "md":
            file_ref_section.append(
                f'\t\t{fr} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = net.daringfireball.markdown; path = {base}; sourceTree = "<group>"; }};'
            )
            bf = uid()
            build_file_section.append(
                f'\t\t{bf} /* {base} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {base} */; }};'
            )
            resource_phase_files.append(f"\t\t\t\t{bf} /* {base} in Resources */,")
        elif kind == "assets":
            file_ref_section.append(
                f'\t\t{fr} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {base}; sourceTree = "<group>"; }};'
            )
            bf = uid()
            build_file_section.append(
                f'\t\t{bf} /* {base} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {base} */; }};'
            )
            resource_phase_files.append(f"\t\t\t\t{bf} /* {base} in Resources */,")
        elif kind == "image":
            file_ref_section.append(
                f'\t\t{fr} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = image.png; path = {base}; sourceTree = "<group>"; }};'
            )
            bf = uid()
            build_file_section.append(
                f'\t\t{bf} /* {base} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {base} */; }};'
            )
            resource_phase_files.append(f"\t\t\t\t{bf} /* {base} in Resources */,")
        elif kind == "plist":
            file_ref_section.append(
                f'\t\t{fr} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {base}; sourceTree = "<group>"; }};'
            )
        folders[folder].append((rel, fr, base))

    for rel in sorted(swift_files):
        add_file(rel, "swift")
    for rel in sorted(md_files):
        add_file(rel, "md")
    for rel in sorted(image_files):
        add_file(rel, "image")
    if assets_rel:
        add_file(assets_rel, "assets")
    if info_rel:
        add_file(info_rel, "plist")

    all_dirs = set()
    for folder in list(folders.keys()):
        parts = folder.split("/") if folder else []
        acc = []
        for p in parts:
            acc.append(p)
            all_dirs.add("/".join(acc))
    all_dirs.add("")

    group_ids = {"": src_group}
    for folder in sorted(all_dirs):
        if folder and folder not in group_ids:
            group_ids[folder] = uid()

    group_blocks = []
    for folder in sorted(all_dirs, key=lambda x: (x.count("/"), x)):
        children = []
        for other in sorted(all_dirs):
            if other and os.path.dirname(other) == folder:
                children.append(
                    f'\t\t\t\t{group_ids[other]} /* {os.path.basename(other)} */,'
                )
        for rel, fr, base in sorted(folders.get(folder, []), key=lambda x: x[2]):
            children.append(f"\t\t\t\t{fr} /* {base} */,")
        gid = group_ids[folder]
        if folder == "":
            group_blocks.append(
                f"""\t\t{gid} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(children)}
\t\t\t);
\t\t\tpath = {name};
\t\t\tsourceTree = "<group>";
\t\t}};"""
            )
        else:
            group_blocks.append(
                f"""\t\t{gid} /* {os.path.basename(folder)} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(children)}
\t\t\t);
\t\t\tpath = {os.path.basename(folder)};
\t\t\tsourceTree = "<group>";
\t\t}};"""
            )

    pbx_out = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_file_section)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_ref_section)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{src_group} /* {name} */,
\t\t\t\t{products_group} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products_group} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_ref} /* {name}.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
{chr(10).join(group_blocks)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* {name} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {config_list_tgt} /* Build configuration list for PBXNativeTarget "{name}" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase} /* Sources */,
\t\t\t\t{frameworks_phase} /* Frameworks */,
\t\t\t\t{resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {name};
\t\t\tproductName = {name};
\t\t\tproductReference = {product_ref} /* {name}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject "{name}" */;
\t\t\tcompatibilityVersion = "Xcode 15.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {products_group} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_id} /* {name} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(resource_phase_files)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(source_phase_files)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{debug_proj} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{release_proj} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{debug_tgt} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = {infoplist};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{release_tgt} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = {infoplist};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{config_list_proj} /* Build configuration list for PBXProject "{name}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_proj} /* Debug */,
\t\t\t\t{release_proj} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{config_list_tgt} /* Build configuration list for PBXNativeTarget "{name}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_tgt} /* Debug */,
\t\t\t\t{release_tgt} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {project_id} /* Project object */;
}}
"""
    os.makedirs(os.path.dirname(pbx_path), exist_ok=True)
    with open(pbx_path, "w") as f:
        f.write(pbx_out)
    print(f"Synced {len(swift_files)} swift files into {name}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
