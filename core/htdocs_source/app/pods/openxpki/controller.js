import Controller from '@ember/controller'
import { tracked } from '@glimmer/tracking'
import { action, set as emSet } from '@ember/object'
import { service } from '@ember/service'
import lite from 'caniuse-lite'
import { detect } from 'detect-browser'
import { A } from '@ember/array'

export default class OpenXpkiController extends Controller {
    @service('oxi-config') config;
    @service('oxi-content') content;
    @service router;

    /*
      Reserved Ember property:
      defines the supported query parameters. Ember makes them available as this.count etc.
      https://api.emberjs.com/ember/release/classes/Controller
    */
    queryParams = [
        "limit",
        "startat",
        "force",
    ];

    // FIXME Remove those three?! (auto-injected by Ember, see queryParams above)
    startat = null;
    limit = null;

    @tracked loading = false;
    @tracked showInfoBlock = false;

    get breadcrumbs() {
        let bc = (this.model.top.page.breadcrumb || []).filter(el => el.label)
        return A(bc) // Ember Array allows to query .lastObject
    }

    get showInfo() {
        return this.model?.top?.right && this.showInfoBlock
    }

    get oldBrowser() {
        const old_age = 2 * 365

        // map detect-browser names to caniuse names
        const map = {
            'edge' : 'edge',
            'edge-ios': 'ios_saf',
            'samsung': 'samsung',
            'edge-chromium': 'edge',
            'chrome': 'chrome',
            'firefox': 'firefox',
            'opera-mini': 'op_mini',
            'opera': 'opera',
            'ie': 'ie',
            'bb10': 'bb',
            'android': 'android',
            'ios': 'ios_saf',
            'safari': 'safari',
        }

        const browser = detect()
        if (!browser) return null

        // translate 'detect-browser' name to 'caniuse' name
        let name = map[browser.name] || browser.name
        if (name == 'chrome' && browser.os.match(/android/i)) name = 'and_chr'
        if (name == 'firefox' && browser.os.match(/android/i)) name = 'and_ff'

        // look if 'caniuse' knows this browser
        let agent = lite.agents[name]
        if (!agent) return null

        // look if 'caniuse' knows this version
        let version = browser.version
        const known_version = Object.keys(agent.release_date).find(v => version.match(new RegExp(`^${v}(\\.|$)`)))
        if (!known_version) return null

        // calculate browser age (release date)
        let release_date = agent.release_date[known_version]
        if (!release_date) return null

        let now = parseInt(new Date() / 1000)
        let age = parseInt((now - release_date) / (60*60*24))

        if (age < old_age) return null

        console.info(`Detected browser "${agent.browser} ${known_version}" is ${age} days old (max. supported browser age: ${old_age} days)`)
        return `${agent.browser} ${known_version}`
    }

    @action
    getStatusClass(level) {
        if (level === "error") { return "alert-danger" }
        if (level === "success") { return "alert-success" }
        if (level === "warn") { return "alert-warning" }
        return "alert-info";
    }

    // We don't use <ddm.LinkTo> but our own method to navigate to target page.
    // This way we can force Ember to do a transition even if the new page is
    // the same page as before by setting parameter "force" a timestamp.
    @action
    navigateTo(page, navbarCollapseFunc, event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        if (navbarCollapseFunc) navbarCollapseFunc()
        this.content.openPage(page, this.content.TARGET.TOP, true)
    }

    @action
    logout(event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        this.content.setTenant(null);
        this.content.openPage('logout', this.content.TARGET.TOP, true)
    }

    @action
    reload() {
        return window.location.reload();
    }

    @action
    toggleInfoBlock() {
        this.showInfoBlock = !this.showInfoBlock;
    }
}