"use strict";

const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
const http = require("http");
const https = require("https");
const crypto = require("crypto");
const childProcess = require("child_process");

const PAGE_FILES = ["index.dkml", "index.dkss", "index.js", "index.json"];
const PAGE_FILE_ITEMS = [
  { label: "DKML", file: "index.dkml", icon: "symbol-structure" },
  { label: "DKSS", file: "index.dkss", icon: "symbol-color" },
  { label: "JS", file: "index.js", icon: "symbol-method" },
  { label: "JSON", file: "index.json", icon: "json" },
  { label: "Compiled", file: "index.dynamic.json", icon: "preview" }
];
const DKML_WORDS = ["page", "view", "text", "image", "input", "textarea", "button", "card", "row", "column", "icon", "space", "selectable-card", "tableview", "collectionview", "class", "bindtap", "dk:if", "dk:for", "dk:item", "dk:index", "dk:key", "columns", "slot", "src", "placeholder", "name", "state-key", "value", "default", "default-text", "keyboard-type", "max-length", "data-id"];
const DKSS_WORDS = ["background-color", "text-color", "font-size", "font-weight", "corner-radius", "border-width", "border-color", "width", "height", "margin", "padding", "alignment", "text-align", "stack-alignment", "distribution", "spacing", "content-mode", "number-of-lines", "hidden"];
const JS_WORDS = ["Page", "data", "methods", "event", "dataset", "dk.setState", "dk.navigate", "dk.navigateNative", "dk.back", "dk.toast", "dk.track", "dk.request", "dk.delay", "params", "responseKey", "success", "fail", "failure", "showLoading", "loadingText", "selectedCardId", "pageParams"];
const JSON_WORDS = ["schemaVersion", "pageId", "pageTitle", "backgroundColor", "pageParams", "onLoad", "apiKey", "params", "responseKey", "showLoading", "loadingText", "navigationBar"];

function activate(context) {
  const state = new StudioState(context);
  const pagesProvider = new PagesProvider(state);
  const previewProvider = new PreviewViewProvider(state);
  const diagnostics = vscode.languages.createDiagnosticCollection("dynamicpagekit");
  state.pagesProvider = pagesProvider;
  state.previewProvider = previewProvider;
  state.diagnostics = diagnostics;

  context.subscriptions.push(diagnostics);
  context.subscriptions.push(vscode.window.registerTreeDataProvider("dynamicPageKit.pages", pagesProvider));
  context.subscriptions.push(vscode.window.registerWebviewViewProvider("dynamicPageKit.preview", previewProvider));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.refreshPages", () => state.refreshPages()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.openPage", item => state.openPage(item)));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.newPage", () => state.newPage()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.deletePage", item => state.deletePage(item)));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.importJSON", () => state.importJSON()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.importJSONBatch", () => state.importJSONBatch()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.compileActive", () => state.saveAndCompile()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.validateActive", () => state.validateActivePage()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.validateProject", () => state.validateProject()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.exportJSONPackage", () => state.exportJSONPackage()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.packageAndUpload", () => state.packageAndUpload()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.startPreviewService", () => state.startPreviewService()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.stopPreviewService", () => state.stopPreviewService()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.startPreview", () => state.startPreview()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.restartHost", () => state.restartHost()));
  context.subscriptions.push(vscode.commands.registerCommand("dynamicPageKit.refreshPreview", () => state.refreshPreview()));

  registerLanguageFeatures(context, state);

  const watcher = vscode.workspace.createFileSystemWatcher("**/pages/**/index.{dkml,dkss,js,json}");
  context.subscriptions.push(watcher);
  watcher.onDidChange(uri => state.onSourceChanged(uri));
  watcher.onDidCreate(uri => state.onSourceChanged(uri));
  watcher.onDidDelete(() => state.refreshPages());
  context.subscriptions.push(vscode.workspace.onDidSaveTextDocument(doc => state.onDocumentSaved(doc)));
  context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(event => {
    if (event.affectsConfiguration("dynamicPageKit")) {
      state.reloadConfiguration();
    }
  }));

  state.start();
}

function deactivate() {}

class StudioState {
  constructor(context) {
    this.context = context;
    this.pages = [];
    this.activePageName = context.workspaceState.get("dynamicPageKit.activePage");
    this.revision = 0;
    this.activeJSON = "{}";
    this.compiledPages = [];
    this.lastLog = "";
    this.status = "Idle";
    this.server = undefined;
    this.pagesProvider = undefined;
    this.previewProvider = undefined;
    this.diagnostics = undefined;
    this.statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
    this.statusBar.command = "dynamicPageKit.startPreview";
    context.subscriptions.push(this.statusBar);
    this.reloadConfiguration();
  }

  reloadConfiguration() {
    const config = vscode.workspace.getConfiguration("dynamicPageKit");
    this.port = config.get("previewPort", 8088);
    this.hostProjectPath = config.get("hostProjectPath", "");
    this.backendBaseURL = String(config.get("backendBaseURL", "") || "").trim();
    this.backendToken = String(config.get("backendToken", "") || "").trim();
    this.backendProjectKey = String(config.get("projectKey", "") || "").trim();
    this.backendProjectName = String(config.get("projectName", "") || "").trim();
    this.backendOperator = String(config.get("operator", "") || "").trim();
    this.dpkSecret = String(config.get("dpkSecret", "") || "");
    this.workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    this.projectRoot = this.workspaceRoot;
    this.packageRoot = this.tryResolveHostProjectPath();
  }

  async start() {
    this.ensurePreviewServer();
    await this.refreshPages();
    this.updateStatus("DynamicPageKit ready");
  }

  async refreshPages() {
    this.pages = scanPages(this.projectRoot);
    if (!this.activePageName || !this.pages.some(page => page.name === this.activePageName)) {
      this.activePageName = this.pages[0]?.name;
    }
    await this.context.workspaceState.update("dynamicPageKit.activePage", this.activePageName);
    this.pagesProvider?.refresh();
    await this.compileActive({ silent: true });
  }

  async openPage(item) {
    const page = item?.page || await this.pickPage();
    if (!page) { return; }
    this.activePageName = page.name;
    await this.context.workspaceState.update("dynamicPageKit.activePage", page.name);
    this.pagesProvider?.refresh();
    if (item?.file) {
      await this.openPageFile(page, item.file);
    } else {
      await this.openPageFile(page, "index.dkml");
    }
    await this.compileActive();
  }

  async openPageFile(page, fileName) {
    const filePath = path.join(page.dir, fileName);
    if (!fs.existsSync(filePath)) {
      if (fileName === "index.dynamic.json") {
        await this.compileActive({ silent: true });
        const compiled = this.compiledPages.find(candidate => candidate.name === page.name);
        if (compiled?.jsonText) {
          fs.writeFileSync(filePath, compiled.jsonText);
        }
      }
    }
    if (!fs.existsSync(filePath)) {
      vscode.window.showWarningMessage(`${fileName} does not exist in ${page.name}`);
      return;
    }
    const document = await vscode.workspace.openTextDocument(filePath);
    await vscode.window.showTextDocument(document, { preview: false });
  }

  async newPage() {
    if (!this.projectRoot) {
      vscode.window.showErrorMessage("Open a workspace before creating a DynamicPageKit page.");
      return;
    }
    const name = await vscode.window.showInputBox({ prompt: "Page directory name", value: "NewPage" });
    if (!name) { return; }
    const safeName = sanitizeName(name);
    const pagesRoot = path.join(this.projectRoot, "pages");
    const pageDir = uniqueDirectory(pagesRoot, safeName);
    fs.mkdirSync(pageDir, { recursive: true });
    fs.writeFileSync(path.join(pageDir, "index.dkml"), `<page class="page">\n  <text class="title">Hello DynamicPageKit</text>\n  <button class="primary-button" bindtap="goNext">View Detail</button>\n</page>\n`);
    fs.writeFileSync(path.join(pageDir, "index.dkss"), `.page {\n  background-color: #FFFFFF;\n}\n\n.title {\n  margin: 24 16 12 16;\n  font-size: 20;\n  font-weight: semibold;\n  text-color: #111111;\n}\n\n.primary-button {\n  height: 44;\n  margin: 12 16 0 16;\n  background-color: #2F80ED;\n  text-color: #FFFFFF;\n  corner-radius: 8;\n}\n`);
    fs.writeFileSync(path.join(pageDir, "index.js"), `Page({\n  data: {},\n\n  methods: {\n    goNext() {\n      dk.navigate("Detail")\n    }\n  }\n})\n`);
    fs.writeFileSync(path.join(pageDir, "index.json"), `{\n  "schemaVersion": "1.0",\n  "pageId": "${safeName}",\n  "pageTitle": "New Page"\n}\n`);
    await this.refreshPages();
    const page = this.pages.find(candidate => candidate.dir === pageDir);
    if (page) { await this.openPage({ page }); }
  }

  async deletePage(item) {
    const page = item?.page || await this.pickPage();
    if (!page) { return; }

    const confirmation = await vscode.window.showWarningMessage(
      `Delete DynamicPageKit page "${page.name}"? This will remove the whole page directory.`,
      { modal: true },
      "Delete Page"
    );
    if (confirmation !== "Delete Page") { return; }

    await this.closeEditorsForPage(page);
    await vscode.workspace.fs.delete(vscode.Uri.file(page.dir), { recursive: true, useTrash: true });

    if (this.activePageName === page.name) {
      this.activePageName = undefined;
      await this.context.workspaceState.update("dynamicPageKit.activePage", undefined);
    }

    await this.refreshPages();
    vscode.window.showInformationMessage(`Deleted DynamicPageKit page "${page.name}".`);
  }

  async closeEditorsForPage(page) {
    const tabs = vscode.window.tabGroups.all.flatMap(group => group.tabs);
    for (const tab of tabs) {
      const uri = tab.input?.uri;
      if (uri?.fsPath && isPathInside(uri.fsPath, page.dir)) {
        await vscode.window.tabGroups.close(tab);
      }
    }
  }

  async importJSON() {
    if (!this.projectRoot) {
      vscode.window.showErrorMessage("Open a workspace before importing JSON.");
      return;
    }
    const selection = await vscode.window.showOpenDialog({ canSelectMany: false, filters: { JSON: ["json"] } });
    if (!selection?.[0]) { return; }
    const defaultName = path.basename(selection[0].fsPath, ".json");
    const name = await vscode.window.showInputBox({ prompt: "Output page directory name", value: sanitizeName(defaultName) });
    if (!name) { return; }
    const pageDir = uniqueDirectory(path.join(this.projectRoot, "pages"), sanitizeName(name));
    await this.runCLI(["decompile-json", "--json", selection[0].fsPath, "--out-dir", pageDir]);
    await this.refreshPages();
    const page = this.pages.find(candidate => candidate.dir === pageDir);
    if (page) { await this.openPage({ page }); }
  }

  async importJSONBatch() {
    if (!this.projectRoot) {
      vscode.window.showErrorMessage("Open a workspace before importing JSON.");
      return;
    }

    const selection = await vscode.window.showOpenDialog({
      canSelectMany: true,
      filters: { JSON: ["json"] },
      openLabel: "Import JSON Files"
    });
    if (!selection?.length) { return; }

    const pagesRoot = path.join(this.projectRoot, "pages");
    const imported = [];
    const failed = [];

    await vscode.window.withProgress({
      location: vscode.ProgressLocation.Notification,
      title: "Importing DynamicPageKit JSON pages",
      cancellable: false
    }, async progress => {
      for (let index = 0; index < selection.length; index += 1) {
        const uri = selection[index];
        const baseName = sanitizeName(path.basename(uri.fsPath, ".json"));
        const pageDir = uniqueDirectory(pagesRoot, baseName || "ImportedPage");
        progress.report({ message: `${index + 1}/${selection.length} ${path.basename(uri.fsPath)}` });

        try {
          await this.runCLI(["decompile-json", "--json", uri.fsPath, "--out-dir", pageDir]);
          imported.push({ name: path.basename(pageDir), dir: pageDir });
        } catch (error) {
          failed.push(`${path.basename(uri.fsPath)}: ${error.message || String(error)}`);
        }
      }
    });

    await this.refreshPages();

    if (imported.length > 0) {
      const firstPage = this.pages.find(page => page.dir === imported[0].dir);
      if (firstPage) {
        await this.openPage({ page: firstPage });
      }
    }

    if (failed.length > 0) {
      this.lastLog = failed.join("\n");
      this.updateStatus(`Imported ${imported.length}, failed ${failed.length}`);
      vscode.window.showWarningMessage(`Imported ${imported.length} JSON page(s), ${failed.length} failed. See Preview log for details.`);
    } else {
      this.updateStatus(`Imported ${imported.length} JSON page(s)`);
      vscode.window.showInformationMessage(`Imported ${imported.length} DynamicPageKit JSON page(s).`);
    }
    this.previewProvider?.refresh();
  }

  async compileActive(options = {}) {
    if (!this.projectRoot || !this.activePageName) {
      this.publishPreview(makeStatusPageJSON("no_active_page", "没有可预览页面", "请先在 Pages 中新建页面或导入 JSON。"), [], undefined);
      return;
    }
    try {
      const output = await this.runCLI(["compile-project", "--project-dir", this.projectRoot, "--active", this.activePageName]);
      const result = JSON.parse(output || "{}");
      this.compiledPages = result.pages || [];
      const active = result.activePage || this.activePageName;
      this.activePageName = active;
      this.applyDiagnostics(result.pages || []);
      const activeJSON = activeRuntimeJSON(result, active);
      if (activeJSON) {
        this.publishPreview(activeJSON, result.pages || [], active);
      } else {
        const message = [
          "没有找到可发布到预览的页面。",
          `Project root: ${this.projectRoot}`,
          `Active page: ${this.activePageName || "-"}`,
          `Pages compiled: ${(result.pages || []).length}`,
          `CLI diagnostics: ${(result.diagnostics || []).join("; ") || "-"}`
        ].join("\n");
        this.lastLog = message;
        this.publishPreview(makeStatusPageJSON("empty_compile_result", "未生成预览页面", message), result.pages || [], active);
      }
      this.updateStatus(`Compiled ${active || "-"}`);
      this.pagesProvider?.refresh();
      this.previewProvider?.refresh();
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Compile failed");
      this.publishPreview(makeStatusPageJSON("compile_failed", "页面编译失败", this.lastLog), this.compiledPages || [], this.activePageName);
      this.previewProvider?.refresh();
      if (!options.silent) {
        vscode.window.showErrorMessage(`DynamicPageKit compile failed: ${this.lastLog}`);
      }
    }
  }

  async saveAndCompile() {
    await vscode.workspace.saveAll(false);
    await this.compileActive();
  }

  async validateActivePage() {
    if (!this.activePageName) {
      vscode.window.showWarningMessage("No active DynamicPageKit page to validate.");
      return;
    }
    await this.validateProject({ activeOnly: true });
  }

  async validateProject(options = {}) {
    if (!this.projectRoot) {
      vscode.window.showErrorMessage("Open a workspace before validating DynamicPageKit pages.");
      return;
    }

    await vscode.workspace.saveAll(false);

    try {
      const output = await this.runCLI(["compile-project", "--project-dir", this.projectRoot, "--active", this.activePageName || ""]);
      const result = JSON.parse(output || "{}");
      const pages = result.pages || [];
      const targetPages = options.activeOnly
        ? pages.filter(page => page.name === (result.activePage || this.activePageName))
        : pages;
      this.compiledPages = pages;
      this.applyDiagnostics(pages);

      if (targetPages.length === 0) {
        const expected = path.join(this.projectRoot, "pages", "<PageName>", "index.dkml");
        this.lastLog = [
          options.activeOnly
            ? `Active page not found: ${this.activePageName || "-"}`
            : "No DynamicPageKit pages found.",
          `Project root: ${this.projectRoot}`,
          `Expected page structure: ${expected}`,
          `CLI diagnostics: ${(result.diagnostics || []).join("; ") || "-"}`
        ].join("\n");
        this.updateStatus("Validation failed");
        this.previewProvider?.refresh();
        vscode.window.showWarningMessage("DynamicPageKit validation failed: no pages found. See Preview Last Log.");
        return;
      }

      const failures = targetPages
        .map(page => ({
          name: page.name,
          diagnostics: (page.diagnostics || []).filter(message => message && message !== "编译通过")
        }))
        .filter(page => page.diagnostics.length > 0);

      if (failures.length === 0) {
        const scope = options.activeOnly ? `Active page "${result.activePage || this.activePageName}"` : `${targetPages.length} page(s)`;
        const active = result.activePage || this.activePageName;
        const activeJSON = activeRuntimeJSON(result, active);
        if (activeJSON) {
          this.publishPreview(activeJSON, pages, active);
        }
        this.lastLog = `${scope} validated successfully.`;
        this.updateStatus("Validation passed");
        this.previewProvider?.refresh();
        vscode.window.showInformationMessage(`DynamicPageKit validation passed: ${scope}.`);
      } else {
        this.lastLog = failures.map(page => `${page.name}\n${page.diagnostics.map(message => `- ${message}`).join("\n")}`).join("\n\n");
        this.updateStatus("Validation failed");
        this.previewProvider?.refresh();
        vscode.window.showWarningMessage(`DynamicPageKit validation found ${failures.length} page(s) with diagnostics. See Problems or Preview Last Log.`);
      }
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Validation failed");
      this.previewProvider?.refresh();
      vscode.window.showErrorMessage(`DynamicPageKit validation failed: ${this.lastLog}`);
    }
  }

  async exportJSONPackage() {
    if (!this.projectRoot) {
      vscode.window.showErrorMessage("Open a workspace before exporting DynamicPageKit .dpk package.");
      return;
    }

    const secret = this.dpkSecretBuffer("Export");
    if (!secret) { return; }

    const releaseInfo = await this.collectReleaseInfo("Export");
    if (!releaseInfo) { return; }

    let runtimePackage;
    try {
      runtimePackage = await this.buildRuntimePackage({ allowDiagnosticsPrompt: true, operation: "Export" });
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Export failed");
      vscode.window.showErrorMessage(`DynamicPageKit export failed: ${this.lastLog}`);
      return;
    }

    const defaultName = `${sanitizeName(path.basename(this.projectRoot || "DynamicPageKit"))}.dpk`;
    const target = await vscode.window.showSaveDialog({
      defaultUri: vscode.Uri.file(path.join(this.projectRoot, defaultName)),
      filters: { "DynamicPageKit Package": ["dpk"] },
      saveLabel: "Export DPK"
    });
    if (!target) { return; }

    try {
      const dpkFile = createDPKPackage(runtimePackage, releaseInfo, secret);
      fs.writeFileSync(target.fsPath, dpkFile.content);
      this.lastLog = [
        "Export succeeded.",
        `File: ${target.fsPath}`,
        `Release: ${releaseInfo.releaseTitle}`,
        `Page count: ${runtimePackage.manifest.pages.length}`
      ].join("\n");
      this.updateStatus(`Exported ${runtimePackage.manifest.pages.length} page(s) as .dpk`);
      this.previewProvider?.refresh();
      vscode.window.showInformationMessage(`Exported DynamicPageKit .dpk package: ${target.fsPath}`);
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Export failed");
      this.previewProvider?.refresh();
      vscode.window.showErrorMessage(`DynamicPageKit export failed: ${this.lastLog}`);
    }
  }

  async packageAndUpload() {
    if (!this.projectRoot) {
      vscode.window.showErrorMessage("Open a workspace before uploading DynamicPageKit package.");
      return;
    }

    const backend = await this.backendUploadConfiguration();
    if (!backend) { return; }

    const secret = this.dpkSecretBuffer("Upload");
    if (!secret) { return; }

    const releaseInfo = await this.collectReleaseInfo("Upload");
    if (!releaseInfo) { return; }

    let runtimePackage;
    try {
      runtimePackage = await this.buildRuntimePackage({ allowDiagnosticsPrompt: true, operation: "Upload" });
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Upload failed");
      this.previewProvider?.refresh();
      vscode.window.showErrorMessage(`DynamicPageKit upload failed: ${this.lastLog}`);
      return;
    }

    try {
      this.updateStatus("Encrypting package");
      this.previewProvider?.refresh();
      const dpkFile = createDPKPackage(runtimePackage, releaseInfo, secret);
      this.updateStatus("Uploading package");
      const response = await uploadRuntimePackage(backend, runtimePackage, dpkFile, releaseInfo);
      const data = response.data || {};
      const summary = formatUploadSummary(data, runtimePackage);
      this.lastLog = [
        "Upload succeeded.",
        `Backend: ${backend.baseURL}`,
        `Project: ${backend.projectKey}`,
        `Release: ${releaseInfo.releaseTitle}`,
        summary
      ].filter(Boolean).join("\n");
      this.updateStatus("Upload succeeded");
      this.previewProvider?.refresh();
      vscode.window.showInformationMessage(`DynamicPageKit upload succeeded: ${summary}`);
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Upload failed");
      this.previewProvider?.refresh();
      vscode.window.showErrorMessage(`DynamicPageKit upload failed: ${this.lastLog}`);
    }
  }

  dpkSecretBuffer(operation) {
    const value = String(this.dpkSecret || "");
    if (!value.trim()) {
      vscode.window.showErrorMessage(`Configure dynamicPageKit.dpkSecret before ${String(operation || "export").toLowerCase()}ing .dpk packages.`);
      return undefined;
    }
    return Buffer.from(value, "utf8");
  }

  async collectReleaseInfo(operation) {
    const defaultTitle = `${formatLocalMinute(new Date())} 更新`;
    const releaseTitle = await vscode.window.showInputBox({
      prompt: `${operation || "Package"} title shown in backend`,
      value: defaultTitle,
      validateInput: value => String(value || "").trim() ? undefined : "Title is required."
    });
    if (!releaseTitle) { return undefined; }

    const releaseDescription = await vscode.window.showInputBox({
      prompt: "Release description shown in backend. Use \\n for line breaks.",
      placeHolder: "例如：更新 ETC 绑定页文案；修复确认弹窗布局",
      value: ""
    });
    if (releaseDescription === undefined) { return undefined; }

    return {
      releaseTitle: releaseTitle.trim(),
      releaseDescription: String(releaseDescription || "").replace(/\\n/g, "\n"),
      generatedAt: new Date().toISOString()
    };
  }

  async buildRuntimePackage(options = {}) {
    await vscode.workspace.saveAll(false);

    const output = await this.runCLI(["compile-project", "--project-dir", this.projectRoot, "--active", this.activePageName || ""]);
    const result = JSON.parse(output || "{}");
    const pages = result.pages || [];
    this.compiledPages = pages;
    this.applyDiagnostics(pages);

    if (pages.length === 0) {
      const expected = path.join(this.projectRoot, "pages", "<PageName>", "index.dkml");
      throw new Error([
        "No DynamicPageKit pages found.",
        `Project root: ${this.projectRoot}`,
        `Expected page structure: ${expected}`,
        `CLI diagnostics: ${(result.diagnostics || []).join("; ") || "-"}`
      ].join("\n"));
    }

    const failedPages = pages.filter(page => (page.diagnostics || []).some(message => message && message !== "编译通过"));
    if (failedPages.length > 0 && options.allowDiagnosticsPrompt) {
      const choice = await vscode.window.showWarningMessage(
        `${failedPages.length} page(s) have diagnostics. ${options.operation || "Continue"} anyway?`,
        { modal: true },
        `${options.operation || "Continue"} Anyway`
      );
      if (choice !== `${options.operation || "Continue"} Anyway`) {
        throw new Error(`${options.operation || "Operation"} cancelled because diagnostics were found.`);
      }
    } else if (failedPages.length > 0) {
      throw new Error(`${failedPages.length} page(s) have diagnostics.`);
    }

    const active = result.activePage || this.activePageName || pages[0]?.name;
    const activeJSON = activeRuntimeJSON(result, active);
    if (activeJSON) {
      this.publishPreview(activeJSON, pages, active);
    }

    const manifest = {
      name: sanitizeName(path.basename(this.projectRoot || "DynamicPageKit")),
      generatedAt: new Date().toISOString(),
      sourceProject: this.projectRoot,
      activePage: active,
      pages: []
    };
    const pagesMap = {};

    for (const page of pages) {
      if (!page.jsonText) { continue; }
      try {
        pagesMap[page.name] = JSON.parse(page.jsonText);
      } catch {
        throw new Error(`Invalid runtime JSON generated for page: ${page.name}`);
      }
      manifest.pages.push({
        name: page.name,
        pageId: page.pageId || null
      });
    }

    if (manifest.pages.length === 0) {
      throw new Error("No runtime JSON page files generated.");
    }

    return { manifest, pages: pagesMap, result };
  }

  async backendUploadConfiguration() {
    const missing = [];
    if (!this.backendBaseURL) { missing.push("dynamicPageKit.backendBaseURL"); }
    if (!this.backendToken) { missing.push("dynamicPageKit.backendToken"); }
    if (missing.length > 0) {
      vscode.window.showErrorMessage(`Configure ${missing.join(", ")} before uploading DynamicPageKit package.`);
      return undefined;
    }

    const defaultProjectKey = sanitizeName(this.backendProjectKey || path.basename(this.projectRoot || "DynamicPageKitProject"));
    const inputProjectKey = await vscode.window.showInputBox({
      prompt: "Backend project key for this uploaded DynamicPageKit package",
      placeHolder: "for example: etc_bind",
      value: defaultProjectKey,
      validateInput: value => {
        const sanitized = sanitizeName(value);
        if (!sanitized) { return "Project key is required."; }
        return undefined;
      }
    });
    if (!inputProjectKey) { return undefined; }
    const projectKey = sanitizeName(inputProjectKey);

    const baseURL = normalizeBackendBaseURL(this.backendBaseURL);
    try {
      new URL(baseURL);
    } catch {
      vscode.window.showErrorMessage(`Invalid dynamicPageKit.backendBaseURL: ${this.backendBaseURL}`);
      return undefined;
    }

    return {
      baseURL,
      token: this.backendToken,
      projectKey,
      projectName: this.backendProjectName || projectKey,
      operator: this.backendOperator || ""
    };
  }

  async startPreview() {
    await this.startPreviewService({ silent: true });
    await this.compileActive({ silent: true });
    try {
      const hostRoot = this.resolveHostProjectPath();
      const device = await this.selectSimulatorDevice();
      this.updateStatus(`Building ${device.name}`);
      const derivedData = path.join(hostRoot, ".build", "VSCodeSimulatorPreviewDerivedData");
      await execFile("/usr/bin/xcodebuild", ["-project", path.join(hostRoot, "MojuKitPreview.xcodeproj"), "-scheme", "MojuKitPreview", "-configuration", "Debug", "-destination", `platform=iOS Simulator,id=${device.udid}`, "-derivedDataPath", derivedData, "-quiet", "build"], { cwd: hostRoot });
      await this.bootDevice(device.udid);
      const appPath = path.join(derivedData, "Build", "Products", "Debug-iphonesimulator", "MojuKitPreview.app");
      await execFile("/usr/bin/xcrun", ["simctl", "install", device.udid, appPath]);
      await execFile("/usr/bin/open", ["-a", "Simulator"]).catch(() => "");
      await execFile("/usr/bin/xcrun", ["simctl", "terminate", device.udid, "com.demo.MojuKitPreview"]).catch(() => "");
      const launchOutput = await execFile("/usr/bin/xcrun", ["simctl", "launch", device.udid, "com.demo.MojuKitPreview", "--dynamicpage-preview-host"]);
      this.lastLog = launchOutput.trim();
      this.updateStatus(`${device.name} preview running`);
      this.previewProvider?.refresh();
    } catch (error) {
      this.lastLog = error.message || String(error);
      this.updateStatus("Preview failed");
      this.previewProvider?.refresh();
      vscode.window.showErrorMessage(`DynamicPageKit preview failed: ${this.lastLog}`);
    }
  }

  async restartHost() {
    await this.startPreview();
  }

  async startPreviewService(options = {}) {
    this.ensurePreviewServer();
    await this.compileActive({ silent: true });
    const message = `DynamicPageKit preview service: http://127.0.0.1:${this.port}`;
    this.updateStatus(`Preview service on ${this.port}`);
    this.previewProvider?.refresh();
    if (!options.silent) {
      vscode.window.showInformationMessage(message);
    }
  }

  async stopPreviewService(options = {}) {
    const server = this.server;
    if (!server) {
      this.updateStatus("Preview service stopped");
      this.previewProvider?.refresh();
      if (!options.silent) {
        vscode.window.showInformationMessage("DynamicPageKit preview service is already stopped.");
      }
      return;
    }

    await new Promise(resolve => {
      if (!server.listening) {
        resolve();
        return;
      }
      server.close(error => {
        if (error) {
          this.lastLog = error.message || String(error);
        }
        resolve();
      });
    });

    if (this.server === server) {
      this.server = undefined;
    }
    this.updateStatus("Preview service stopped");
    this.previewProvider?.refresh();
    if (!options.silent) {
      vscode.window.showInformationMessage("DynamicPageKit preview service stopped.");
    }
  }

  async refreshPreview() {
    await this.compileActive();
  }

  async updateHostProjectPath(hostProjectPath) {
    const trimmed = String(hostProjectPath || "").trim();
    if (!trimmed) {
      vscode.window.showWarningMessage("Host project path cannot be empty.");
      return;
    }
    if (!fs.existsSync(path.join(trimmed, "Package.swift")) || !fs.existsSync(path.join(trimmed, "MojuKitPreview.xcodeproj"))) {
      vscode.window.showErrorMessage("Host path must contain Package.swift and MojuKitPreview.xcodeproj.");
      return;
    }

    await vscode.workspace.getConfiguration("dynamicPageKit").update("hostProjectPath", trimmed, vscode.ConfigurationTarget.Workspace);
    await this.context.globalState.update("dynamicPageKit.hostProjectPath", trimmed);
    this.hostProjectPath = trimmed;
    this.packageRoot = trimmed;
    this.updateStatus("Host path updated");
    this.previewProvider?.refresh();
  }

  async setActivePageByName(pageName) {
    const page = this.pages.find(candidate => candidate.name === pageName);
    if (!page) {
      vscode.window.showWarningMessage(`DynamicPageKit page not found: ${pageName}`);
      return;
    }
    await this.openPage({ page });
  }

  async onDocumentSaved(document) {
    if (isDynamicPageSource(document.uri.fsPath)) {
      await this.compileActive({ silent: true });
    }
  }

  async onSourceChanged(uri) {
    if (isDynamicPageSource(uri.fsPath)) {
      await this.refreshPages();
    }
  }

  async runCLI(args) {
    const cwd = this.resolveHostProjectPath();
    return execFile("swift", ["run", "DynamicPageKitCLI", ...args], { cwd });
  }

  tryResolveHostProjectPath() {
    try {
      return this.resolveHostProjectPath();
    } catch {
      return undefined;
    }
  }

  resolveHostProjectPath() {
    const candidates = [];
    if (this.hostProjectPath) { candidates.push(this.hostProjectPath); }
    const rememberedHostProjectPath = this.context.globalState.get("dynamicPageKit.hostProjectPath");
    if (rememberedHostProjectPath) { candidates.push(rememberedHostProjectPath); }
    if (this.workspaceRoot) {
      candidates.push(this.workspaceRoot);
      candidates.push(path.dirname(this.workspaceRoot));
    }
    candidates.push("/Users/wangleihaoshuaio/Developer/Demo/MojuKit");
    let current = __dirname;
    for (let i = 0; i < 8; i += 1) {
      candidates.push(current);
      current = path.dirname(current);
    }
    for (const candidate of candidates) {
      if (candidate && fs.existsSync(path.join(candidate, "Package.swift")) && fs.existsSync(path.join(candidate, "MojuKitPreview.xcodeproj"))) {
        this.context.globalState.update("dynamicPageKit.hostProjectPath", candidate);
        this.packageRoot = candidate;
        return candidate;
      }
    }
    throw new Error("MojuKitPreview project not found. Set dynamicPageKit.hostProjectPath to the folder containing Package.swift and MojuKitPreview.xcodeproj.");
  }

  ensurePreviewServer() {
    if (this.server?.listening) { return; }
    if (this.server && !this.server.listening) {
      this.server.close?.();
      this.server = undefined;
    }
    this.server = http.createServer((request, response) => {
      const url = new URL(request.url || "/", `http://127.0.0.1:${this.port}`);
      response.setHeader("Access-Control-Allow-Origin", "*");
      response.setHeader("Cache-Control", "no-store");
      response.setHeader("Content-Type", "application/json; charset=utf-8");
      if (url.pathname === "/health") {
        response.end(JSON.stringify({
          ok: true,
          service: "DynamicPageKit VS Code",
          revision: this.revision,
          activePage: this.activePageName,
          projectRoot: this.projectRoot,
          hostProjectPath: this.packageRoot || this.tryResolveHostProjectPath?.()
        }, null, 2));
      } else if (url.pathname === "/active-page.json") {
        response.end(this.activeJSON || "{}");
      } else if (url.pathname === "/events") {
        response.end(JSON.stringify({ revision: this.revision }));
      } else if (url.pathname === "/manifest.json") {
        response.end(JSON.stringify({
          name: "DynamicPageKit VS Code",
          revision: this.revision,
          activePage: this.activePageName,
          activePagePath: "/active-page.json",
          eventsPath: "/events",
          pages: this.compiledPages.map(page => ({ name: page.name, pageId: page.pageId, path: `/page/${encodeURIComponent(page.name)}.json` }))
        }, null, 2));
      } else if (url.pathname === "/dynamic/runtime/manifest") {
        const projectKey = url.searchParams.get("projectKey") || "";
        response.end(JSON.stringify({
          projectKey: projectKey,
          name: "DynamicPageKit VS Code",
          activePage: this.activePageName,
          pages: this.compiledPages.map(page => ({
            name: page.name,
            pageId: page.pageId,
            path: `/dynamic/runtime/page?projectKey=${encodeURIComponent(projectKey)}&page=${encodeURIComponent(page.name)}`
          }))
        }, null, 2));
      } else if (url.pathname === "/dynamic/runtime/page") {
        const pageName = url.searchParams.get("page") || "";
        const page = matchPage(pageName, this.compiledPages);
        if (page) {
          response.end(page.jsonText);
        } else {
          response.statusCode = 404;
          response.end(JSON.stringify({ error: "page_not_found", message: `Page not found: ${pageName}` }));
        }
      } else if (url.pathname === "/dynamic/runtime/package") {
        const projectKey = url.searchParams.get("projectKey") || "";
        const pagesMap = {};
        for (const page of this.compiledPages) {
          if (page.jsonText) {
            try {
              pagesMap[page.name] = JSON.parse(page.jsonText);
            } catch (e) {
              // ignore
            }
          }
        }
        response.end(JSON.stringify({
          projectKey: projectKey,
          manifest: {
            projectKey: projectKey,
            name: "DynamicPageKit VS Code",
            activePage: this.activePageName,
            pages: this.compiledPages.map(page => ({
              name: page.name,
              pageId: page.pageId,
              path: `/dynamic/runtime/page?projectKey=${encodeURIComponent(projectKey)}&page=${encodeURIComponent(page.name)}`
            }))
          },
          pages: pagesMap
        }, null, 2));
      } else if (url.pathname.startsWith("/page/") && url.pathname.endsWith(".json")) {
        const target = decodeURIComponent(url.pathname.slice("/page/".length, -".json".length));
        const page = matchPage(target, this.compiledPages);
        if (page) {
          response.end(page.jsonText);
        } else {
          response.statusCode = 404;
          response.end(JSON.stringify({ error: "page_not_found" }));
        }
      } else {
        response.end(JSON.stringify({ name: "DynamicPageKit VS Code", activePage: "/active-page.json", events: "/events", manifest: "/manifest.json" }));
      }
    });
    this.server.on("error", error => {
      this.lastLog = error.message || String(error);
      this.updateStatus("Preview service failed");
      this.previewProvider?.refresh();
      vscode.window.showErrorMessage(`DynamicPageKit preview service failed: ${this.lastLog}`);
      this.server = undefined;
    });
    this.server.listen(this.port, "127.0.0.1", () => this.updateStatus(`Preview service on ${this.port}`));
  }

  publishPreview(jsonText, pages, activePage) {
    this.activeJSON = jsonText || makeStatusPageJSON("empty_preview", "暂无预览内容", "请先新建页面或导入 JSON。");
    this.compiledPages = pages || [];
    this.activePageName = activePage || this.activePageName;
    this.revision += 1;
    this.previewProvider?.refresh();
    this.statusBar.text = `DPK rev ${this.revision}`;
    this.statusBar.show();
  }

  applyDiagnostics(pages) {
    this.diagnostics?.clear();
    for (const page of pages) {
      const messages = (page.diagnostics || []).filter(message => message && message !== "编译通过");
      if (messages.length === 0) { continue; }
      const filePath = diagnosticFileForPage(page.path, messages);
      const uri = vscode.Uri.file(filePath);
      this.diagnostics?.set(uri, messages.map(message => {
        const severity = message.includes("失败") || message.includes("没有找到") ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning;
        return new vscode.Diagnostic(new vscode.Range(0, 0, 0, 200), message, severity);
      }));
    }
  }

  async selectSimulatorDevice() {
    const output = await execFile("/usr/bin/xcrun", ["simctl", "list", "devices", "available", "--json"]);
    const json = JSON.parse(output);
    const devices = Object.values(json.devices || {}).flat().filter(device => device.name && device.name.includes("iPhone") && device.isAvailable !== false);
    if (devices.length === 0) { throw new Error("No available iPhone Simulator found."); }
    devices.sort((a, b) => scoreDevice(a) - scoreDevice(b));
    return devices[0];
  }

  async bootDevice(udid) {
    await execFile("/usr/bin/xcrun", ["simctl", "boot", udid]).catch(() => "");
    await execFile("/usr/bin/xcrun", ["simctl", "bootstatus", udid, "-b"]);
  }

  updateStatus(text) {
    this.status = text;
    this.statusBar.text = `DPK: ${text}`;
    this.statusBar.show();
    this.previewProvider?.refresh();
  }

  async pickPage() {
    const picked = await vscode.window.showQuickPick(this.pages.map(page => ({ label: page.name, page })), { placeHolder: "Select DynamicPageKit page" });
    return picked?.page;
  }
}

class PagesProvider {
  constructor(state) {
    this.state = state;
    this.emitter = new vscode.EventEmitter();
    this.onDidChangeTreeData = this.emitter.event;
  }

  refresh() {
    this.emitter.fire();
  }

  getTreeItem(item) {
    if (item.file) {
      const treeItem = new vscode.TreeItem(item.label, vscode.TreeItemCollapsibleState.None);
      treeItem.description = item.file;
      treeItem.contextValue = "dynamicPageKitPageFile";
      treeItem.command = { command: "dynamicPageKit.openPage", title: `Open ${item.label}`, arguments: [item] };
      treeItem.iconPath = new vscode.ThemeIcon(item.icon || "file-code");
      treeItem.resourceUri = vscode.Uri.file(path.join(item.page.dir, item.file));
      return treeItem;
    }

    const treeItem = new vscode.TreeItem(item.page.name, vscode.TreeItemCollapsibleState.Collapsed);
    treeItem.description = item.page.name === this.state.activePageName ? "active" : "";
    treeItem.contextValue = "dynamicPageKitPage";
    treeItem.command = { command: "dynamicPageKit.openPage", title: "Set Active Page", arguments: [item] };
    treeItem.iconPath = new vscode.ThemeIcon(item.page.name === this.state.activePageName ? "play-circle" : "folder");
    return treeItem;
  }

  getChildren(item) {
    if (item?.page && !item.file) {
      return PAGE_FILE_ITEMS.map(fileItem => ({
        page: item.page,
        label: fileItem.label,
        file: fileItem.file,
        icon: fileItem.icon
      }));
    }
    return this.state.pages.map(page => ({ page }));
  }
}

class PreviewViewProvider {
  constructor(state) {
    this.state = state;
    this.view = undefined;
  }

  resolveWebviewView(view) {
    this.view = view;
    view.webview.options = { enableScripts: true };
    view.webview.onDidReceiveMessage(message => this.handleMessage(message));
    this.refresh();
  }

  async handleMessage(message) {
    switch (message?.command) {
      case "startService":
        await this.state.startPreviewService();
        break;
      case "stopService":
        await this.state.stopPreviewService();
        break;
      case "startPreview":
        await this.state.startPreview();
        break;
      case "refreshPreview":
        await this.state.refreshPreview();
        break;
      case "validateActive":
        await this.state.validateActivePage();
        break;
      case "validateProject":
        await this.state.validateProject();
        break;
      case "newPage":
        await this.state.newPage();
        break;
      case "importJSON":
        await this.state.importJSON();
        break;
      case "importJSONBatch":
        await this.state.importJSONBatch();
        break;
      case "exportJSONPackage":
        await this.state.exportJSONPackage();
        break;
      case "packageAndUpload":
        await this.state.packageAndUpload();
        break;
      case "setHostPath":
        await this.state.updateHostProjectPath(message.hostPath);
        break;
      case "setActivePage":
        await this.state.setActivePageByName(message.pageName);
        break;
      default:
        break;
    }
  }

  refresh() {
    if (!this.view) { return; }
    this.view.webview.html = this.html();
  }

  html() {
    const pages = (this.state.compiledPages.length > 0 ? this.state.compiledPages : this.state.pages).map(page => {
      const pageName = page.name;
      const active = pageName === this.state.activePageName;
      return `<li><button class="link page-button ${active ? "active" : ""}" data-page="${escapeHTML(pageName)}">${escapeHTML(pageName)}${active ? " active" : ""}</button></li>`;
    }).join("");
    const hostPath = this.state.packageRoot || this.state.tryResolveHostProjectPath?.() || "Not configured";
    const serviceListening = this.state.server?.listening ? "yes" : "no";
    const backendURL = this.state.backendBaseURL || "Not configured";
    const backendProjectKey = this.state.backendProjectKey || sanitizeName(path.basename(this.state.projectRoot || "DynamicPageKitProject"));
    const backendTokenState = this.state.backendToken ? "configured" : "missing";
    const dpkConfiguredState = this.state.dpkSecret ? "configured" : "missing";
    return `<!doctype html>
<html>
<body style="font-family: var(--vscode-font-family); padding: 12px; color: var(--vscode-foreground); background: var(--vscode-editor-background);">
  <style>
    body { box-sizing: border-box; }
    .actions { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin: 12px 0; }
    button { border: 1px solid var(--vscode-button-border, transparent); background: var(--vscode-button-background); color: var(--vscode-button-foreground); padding: 6px 8px; border-radius: 4px; cursor: pointer; font: inherit; }
    button:hover { background: var(--vscode-button-hoverBackground); }
    input { width: 100%; box-sizing: border-box; margin: 6px 0 8px 0; padding: 6px; border: 1px solid var(--vscode-input-border); background: var(--vscode-input-background); color: var(--vscode-input-foreground); font: inherit; }
    .link { border: 0; background: transparent; color: var(--vscode-textLink-foreground); padding: 2px 0; text-align: left; }
    .link:hover { background: transparent; color: var(--vscode-textLink-activeForeground); text-decoration: underline; }
    .active { font-weight: 600; }
    .meta p { margin: 6px 0; word-break: break-all; }
    pre { white-space: pre-wrap; font-size: 11px; background: var(--vscode-textCodeBlock-background); padding: 8px; border-radius: 4px; }
  </style>
  <h3>DynamicPageKit Preview</h3>
  <div class="actions">
    <button id="startService">启动服务</button>
    <button id="stopService">关闭服务</button>
    <button id="startPreview">启动预览</button>
    <button id="refreshPreview">刷新页面</button>
    <button id="validateActive">校验当前页</button>
    <button id="validateProject">校验全部</button>
    <button id="newPage">新建页面</button>
    <button id="importJSON">导入 JSON</button>
    <button id="importJSONBatch">批量导入</button>
    <button id="exportJSONPackage">导出 DPK 包</button>
    <button id="packageAndUpload">打包并上传</button>
  </div>
  <label for="hostPath"><b>Host 工程路径</b></label>
  <input id="hostPath" value="${escapeAttribute(hostPath === "Not configured" ? "" : hostPath)}" placeholder="/Users/.../MojuKit" />
  <button id="saveHostPath">保存 Host 路径</button>
  <div class="meta">
    <p><b>Status:</b> ${escapeHTML(this.state.status)}</p>
    <p><b>Revision:</b> ${this.state.revision}</p>
    <p><b>Active:</b> ${escapeHTML(this.state.activePageName || "-")}</p>
    <p><b>Service:</b> http://127.0.0.1:${this.state.port}</p>
    <p><b>Service Listening:</b> ${serviceListening}</p>
    <p><b>Health:</b> http://127.0.0.1:${this.state.port}/health</p>
    <p><b>Project:</b> ${escapeHTML(this.state.projectRoot || "-")}</p>
    <p><b>Host:</b> ${escapeHTML(hostPath)}</p>
    <p><b>Backend:</b> ${escapeHTML(backendURL)}</p>
    <p><b>Backend Project:</b> ${escapeHTML(backendProjectKey)}</p>
    <p><b>Backend Token:</b> ${escapeHTML(backendTokenState)}</p>
    <p><b>DPK Secret:</b> ${escapeHTML(dpkConfiguredState)}</p>
  </div>
  <h4>Pages</h4>
  <ul>${pages || "<li>No compiled pages</li>"}</ul>
  <h4>Last Log</h4>
  <pre>${escapeHTML(this.state.lastLog || "No logs")}</pre>
  <script>
    const vscode = acquireVsCodeApi();
    const post = command => vscode.postMessage({ command });
    document.getElementById("startService").addEventListener("click", () => post("startService"));
    document.getElementById("stopService").addEventListener("click", () => post("stopService"));
    document.getElementById("startPreview").addEventListener("click", () => post("startPreview"));
    document.getElementById("refreshPreview").addEventListener("click", () => post("refreshPreview"));
    document.getElementById("validateActive").addEventListener("click", () => post("validateActive"));
    document.getElementById("validateProject").addEventListener("click", () => post("validateProject"));
    document.getElementById("newPage").addEventListener("click", () => post("newPage"));
    document.getElementById("importJSON").addEventListener("click", () => post("importJSON"));
    document.getElementById("importJSONBatch").addEventListener("click", () => post("importJSONBatch"));
    document.getElementById("exportJSONPackage").addEventListener("click", () => post("exportJSONPackage"));
    document.getElementById("packageAndUpload").addEventListener("click", () => post("packageAndUpload"));
    document.getElementById("saveHostPath").addEventListener("click", () => {
      vscode.postMessage({ command: "setHostPath", hostPath: document.getElementById("hostPath").value });
    });
    for (const button of document.querySelectorAll(".page-button")) {
      button.addEventListener("click", () => vscode.postMessage({ command: "setActivePage", pageName: button.dataset.page }));
    }
  </script>
</body>
</html>`;
  }
}

function registerLanguageFeatures(context, state) {
  const completionProvider = {
    provideCompletionItems(document) {
      const words = wordsForDocument(document);
      return words.map(word => new vscode.CompletionItem(word, vscode.CompletionItemKind.Keyword));
    }
  };
  context.subscriptions.push(vscode.languages.registerCompletionItemProvider(["dkml", "dkss", "dynamicpage-js", "json"], completionProvider, ".", "<", ":", "\""));
  context.subscriptions.push(vscode.languages.registerDocumentFormattingEditProvider(["dkml", "dkss", "dynamicpage-js", "json"], {
    async provideDocumentFormattingEdits(document) {
      const kind = kindForDocument(document);
      if (!kind) { return []; }
      let formatted;
      const tempPath = document.uri.fsPath + ".tmp";
      try {
        fs.writeFileSync(tempPath, document.getText(), "utf8");
        formatted = await state.runCLI(["format", "--kind", kind, "--file", tempPath]);
      } catch (err) {
        formatted = formatLocally(kind, document.getText());
      } finally {
        if (fs.existsSync(tempPath)) {
          fs.unlinkSync(tempPath);
        }
      }
      const fullRange = new vscode.Range(document.positionAt(0), document.positionAt(document.getText().length));
      return [vscode.TextEdit.replace(fullRange, formatted)];
    }
  }));
}

function scanPages(root) {
  if (!root || !fs.existsSync(root)) { return []; }
  const scanRoot = fs.existsSync(path.join(root, "pages")) ? path.join(root, "pages") : root;
  const results = [];
  function visit(dir) {
    if (fs.existsSync(path.join(dir, "index.dkml"))) {
      results.push({ name: path.basename(dir), dir });
      return;
    }
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory() && !entry.name.startsWith(".") && entry.name !== "node_modules" && entry.name !== "DerivedData") {
        visit(path.join(dir, entry.name));
      }
    }
  }
  visit(scanRoot);
  return results.sort((a, b) => a.name.localeCompare(b.name));
}

function execFile(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    childProcess.execFile(command, args, { ...options, maxBuffer: 1024 * 1024 * 20 }, (error, stdout, stderr) => {
      if (error) {
        const message = [command, ...args].join(" ") + "\n" + (stderr || stdout || error.message);
        reject(new Error(message.trim()));
      } else {
        resolve(stdout);
      }
    });
  });
}

function uploadRuntimePackage(backend, runtimePackage, dpkFile, releaseInfo) {
  const uploadURL = new URL("/dynamic/projects/upload", backend.baseURL);
  const boundary = `----DynamicPageKit${Date.now().toString(16)}${Math.random().toString(16).slice(2)}`;
  const chunks = [];

  appendMultipartField(chunks, boundary, "projectKey", backend.projectKey);
  appendMultipartField(chunks, boundary, "projectName", backend.projectName || backend.projectKey);
  appendMultipartField(chunks, boundary, "operator", backend.operator || "");
  appendMultipartField(chunks, boundary, "releaseTitle", releaseInfo.releaseTitle);
  appendMultipartField(chunks, boundary, "releaseDescription", releaseInfo.releaseDescription);
  appendMultipartFile(chunks, boundary, "files", dpkFile.fileName, dpkFile.content, dpkFile.contentType || "application/octet-stream");

  chunks.push(Buffer.from(`--${boundary}--\r\n`, "utf8"));
  const body = Buffer.concat(chunks);
  const transport = uploadURL.protocol === "https:" ? https : http;

  return new Promise((resolve, reject) => {
    const request = transport.request({
      method: "POST",
      hostname: uploadURL.hostname,
      port: uploadURL.port || (uploadURL.protocol === "https:" ? 443 : 80),
      path: `${uploadURL.pathname}${uploadURL.search}`,
      headers: {
        "Content-Type": `multipart/form-data; boundary=${boundary}`,
        "Content-Length": body.length,
        "X-DPK-Token": backend.token
      }
    }, response => {
      const responseChunks = [];
      response.on("data", chunk => responseChunks.push(Buffer.from(chunk)));
      response.on("end", () => {
        const text = Buffer.concat(responseChunks).toString("utf8");
        let payload;
        try {
          payload = text ? JSON.parse(text) : {};
        } catch {
          payload = { code: response.statusCode, message: text };
        }

        if ((response.statusCode || 500) >= 400 || payload.code !== 200) {
          reject(new Error(`HTTP ${response.statusCode}: ${payload.message || text || "upload failed"}`));
          return;
        }

        resolve(payload);
      });
    });
    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

function appendMultipartField(chunks, boundary, name, value) {
  chunks.push(Buffer.from(`--${boundary}\r\n`, "utf8"));
  chunks.push(Buffer.from(`Content-Disposition: form-data; name="${escapeMultipartName(name)}"\r\n\r\n`, "utf8"));
  chunks.push(Buffer.from(`${value || ""}\r\n`, "utf8"));
}

function appendMultipartFile(chunks, boundary, name, fileName, content, contentType) {
  chunks.push(Buffer.from(`--${boundary}\r\n`, "utf8"));
  chunks.push(Buffer.from(`Content-Disposition: form-data; name="${escapeMultipartName(name)}"; filename="${escapeMultipartName(fileName)}"\r\n`, "utf8"));
  chunks.push(Buffer.from(`Content-Type: ${contentType}\r\n\r\n`, "utf8"));
  chunks.push(Buffer.isBuffer(content) ? content : Buffer.from(String(content || ""), "utf8"));
  chunks.push(Buffer.from("\r\n", "utf8"));
}

function escapeMultipartName(value) {
  return String(value || "").replace(/["\r\n]/g, "_");
}

function isDynamicPageSource(filePath) {
  return PAGE_FILES.includes(path.basename(filePath));
}

function isPathInside(filePath, directory) {
  const relative = path.relative(directory, filePath);
  return relative === "" || (!!relative && !relative.startsWith("..") && !path.isAbsolute(relative));
}

function diagnosticFileForPage(pageDir, messages) {
  const joined = messages.join("\n");
  if (joined.includes("DKML") || joined.includes("bindtap")) { return path.join(pageDir, "index.dkml"); }
  if (joined.includes("DKSS")) { return path.join(pageDir, "index.dkss"); }
  if (joined.includes("JS")) { return path.join(pageDir, "index.js"); }
  if (joined.includes("JSON")) { return path.join(pageDir, "index.json"); }
  return path.join(pageDir, "index.dkml");
}

function wordsForDocument(document) {
  const kind = kindForDocument(document);
  if (kind === "dkml") { return DKML_WORDS; }
  if (kind === "dkss") { return DKSS_WORDS; }
  if (kind === "js") { return JS_WORDS; }
  if (kind === "json") { return JSON_WORDS; }
  return [];
}

function kindForDocument(document) {
  if (document.languageId === "dkml" || document.fileName.endsWith(".dkml")) { return "dkml"; }
  if (document.languageId === "dkss" || document.fileName.endsWith(".dkss")) { return "dkss"; }
  if (document.languageId === "dynamicpage-js" || document.fileName.endsWith("index.js")) { return "js"; }
  if (document.fileName.endsWith("index.json")) { return "json"; }
  return undefined;
}

function matchPage(target, pages) {
  const normalizedTarget = normalize(target);
  return pages.find(page => normalize(page.name) === normalizedTarget || normalize(page.pageId || "") === normalizedTarget)
    || pages.find(page => normalize(page.name).includes(normalizedTarget) || normalizedTarget.includes(normalize(page.name)));
}

function activeRuntimeJSON(result, activePageName) {
  if (result?.activePageJSON) { return result.activePageJSON; }
  if (result?.activePageJson) { return result.activePageJson; }
  const pages = result?.pages || [];
  const activePage = matchPage(activePageName || result?.activePage || "", pages) || pages[0];
  return activePage?.jsonText || "";
}

function normalize(value) {
  return String(value || "").toLowerCase().replace(/[_\-\s]/g, "");
}

function normalizeBackendBaseURL(value) {
  const trimmed = String(value || "").trim();
  if (!trimmed) { return ""; }
  const withProtocol = /^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed) ? trimmed : `http://${trimmed}`;
  return withProtocol.replace(/\/+$/, "");
}

function scoreDevice(device) {
  if (device.state === "Booted") { return 0; }
  if (device.name.includes("iPhone 17")) { return 1; }
  if (device.name.includes("iPhone 16")) { return 2; }
  if (device.name.includes("iPhone 15")) { return 3; }
  return 10;
}

function sanitizeName(value) {
  return String(value || "NewPage").trim().replace(/[^A-Za-z0-9_-]/g, "_").replace(/_+/g, "_") || "NewPage";
}

function uniqueDirectory(root, name) {
  fs.mkdirSync(root, { recursive: true });
  let candidate = path.join(root, name);
  let index = 2;
  while (fs.existsSync(candidate)) {
    candidate = path.join(root, `${name}${index}`);
    index += 1;
  }
  return candidate;
}

function prettyRuntimeJSON(jsonText) {
  try {
    return JSON.stringify(JSON.parse(jsonText), null, 2) + "\n";
  } catch {
    return String(jsonText || "{}").trimEnd() + "\n";
  }
}

function createDPKPackage(runtimePackage, releaseInfo, secret) {
  const payload = {
    manifest: runtimePackage.manifest,
    pages: runtimePackage.pages,
    releaseTitle: releaseInfo.releaseTitle,
    releaseDescription: releaseInfo.releaseDescription,
    generatedAt: releaseInfo.generatedAt
  };
  const plaintext = Buffer.from(JSON.stringify(payload), "utf8");
  const key = deriveDPKKey(secret);
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  const content = Buffer.concat([Buffer.from("MOJUDPK1", "ascii"), Buffer.from([1]), nonce, ciphertext, tag]);
  return {
    fileName: `${sanitizeName(runtimePackage.manifest.name || "DynamicPageKit")}.dpk`,
    content,
    contentType: "application/octet-stream"
  };
}

function deriveDPKKey(secret) {
  const input = Buffer.isBuffer(secret) ? secret : Buffer.from(String(secret || ""), "utf8");
  return input.length === 32 ? input : crypto.createHash("sha256").update(input).digest();
}

function formatLocalMinute(date) {
  const pad = value => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function formatUploadSummary(data, runtimePackage) {
  const versionName = data.versionName || data.version_name || data.version || "-";
  const status = data.status || "-";
  const pageCount = data.pageCount || data.page_count || runtimePackage.manifest.pages.length;
  const checksum = data.packageChecksum || data.package_checksum || "-";
  return `version=${versionName}, status=${status}, pageCount=${pageCount}, checksum=${checksum}`;
}

function makeStatusPageJSON(pageId, title, message) {
  return JSON.stringify({
    schemaVersion: "1.0",
    pageId,
    pageTitle: title,
    backgroundColor: "#F5F5F5",
    components: [
      {
        type: "text",
        text: title,
        style: {
          marginTop: 80,
          marginLeft: 24,
          marginRight: 24,
          fontSize: 20,
          fontWeight: "semibold",
          textColor: "#111111",
          alignment: "center"
        }
      },
      {
        type: "text",
        text: String(message || ""),
        style: {
          marginTop: 12,
          marginLeft: 24,
          marginRight: 24,
          fontSize: 14,
          textColor: "#666666",
          numberOfLines: 0,
          alignment: "center"
        }
      }
    ]
  });
}

function escapeHTML(value) {
  return String(value).replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char]));
}

function escapeAttribute(value) {
  return escapeHTML(value);
}

function formatLocally(kind, text) {
  if (kind === "json") {
    try { return JSON.stringify(JSON.parse(text), null, 2) + "\n"; } catch { return text; }
  }
  return text;
}

module.exports = { activate, deactivate };
