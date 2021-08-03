import Component from '@glimmer/component';
import { action } from "@ember/object";
import { inject } from '@ember/service';
import { debug } from '@ember/debug';
import ow from 'ow';

/**
 * Implements autofill functionality, e.g. shows a button and sends a request
 * the the backend on button click (or when component is intialized).
 *
 * To use the autofill functionality in any form field, the field's template
 * needs to include the following code:
 * ```html
 * {{#if (has-block "autofill")}}
 *   {{yield this.disableAutofillButton this.setAutofillValue to="autofill"}}
 * {{/if}}
 * ```
 * @param { hash } config - the autofill configuration
 * @param { bool } disabled - set to true to disable the button
 * @param { function } encodeFields - function that encodes the given form fields (see {@link component/oxi-section/form})
 * @param { function } valueSetter - function that processes the server response (will be given the response data)
 * @module component/oxi-section/form/autofill
 */

export default class Autofill extends Component {
    @inject('intl') intl;
    @inject('oxi-backend') backend;

    request;
    autorun;
    label;
    button_label;

    encodeFields;

    fieldRefParams = new Map(); // mapping: (source field name) => (parameter name for autocomplete query)
    valueSetter; // callback passed in from the actual component


    constructor() {
        super(...arguments);

        // Config
        ow(this.args.config, 'config', ow.object.exactShape({
            'request': ow.object.exactShape({
                'url': ow.string,
                'method': ow.optional.string.oneOf(['GET', 'POST']),
                'params': ow.optional.object.exactShape({
                    'user': ow.optional.object,
                    'static': ow.optional.object,
                }),

            }),
            'autorun': ow.optional.any(ow.boolean, ow.number, ow.string.oneOf(['0', '1'])),
            'label': ow.string,
            'button_label': ow.optional.string,
        }));
        this.request = this.args.config.request;
        this.autorun = this.args.config.autorun;
        this.label = this.args.config.label;
        this.button_label = this.args.config.button_label;

        let ref_params = this.request?.params?.user;
        if (ref_params) {
            for (const [param_name, ref_field] of Object.entries(ref_params)) {
                // param_name - parameter name for autocomplete query
                // ref_field - name of another form field whose value to use
                this.fieldRefParams.set(ref_field, param_name);
            }
        }

        // Function to encode fields (from form)
        ow(this.args.encodeFields, 'encodeFields', ow.function);
        this.encodeFields = this.args.encodeFields;

        // Function to set field value (from field instance)
        ow(this.args.valueSetter, 'valueSetter', ow.function);
        this.valueSetter = this.args.valueSetter;

        if (this.autorun) this.query();
    }

    @action
    query() {
        // resolve referenced fields and their values
        let data = {
            ...this.encodeFields(this.fieldRefParams.keys(), this.fieldRefParams), // returns an Object
            ...(this.request.params.static || {}),
        };

        return this.backend.request({
            url: this.request.url,
            method: this.request.method || 'GET',
            data,
        }).then((response) => {
            debug("Autofill response: " + JSON.stringify(response));
            // If OK: unpack JSON data
            if (response?.ok) {
                let data = JSON.stringify(response.json());
                let label = this.intl.t('autofill.result', { target: this.label });
                return this.valueSetter(data, label);
            }
            // Handle non-2xx HTTP status codes
            else {
                console.error(response.status);
                return null;
            }
        });
    }

    get buttonLabel() {
        return (this.button_label
            ? this.button_label
            : this.intl.t('autofill.button', { target: this.label })
        );
    }
}
