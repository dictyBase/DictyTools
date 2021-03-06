(function() {
    YAHOO.namespace('Dicty');
    var Dom = YAHOO.util.Dom;
    var Event = YAHOO.util.Event;

    YAHOO.Dicty.BLAST = function() {
        //var logger = new YAHOO.widget.LogReader();
    };

    YAHOO.lang.augmentProto(YAHOO.Dicty.BLAST, YAHOO.util.AttributeProvider);

    YAHOO.Dicty.BLAST.prototype.init = function() {
        /* --- BLAST Controls --- */
        this.blastProgramDropDown = Dom.get('blast-program-option');
        this.blastProgramInfo = Dom.get('blast-program-option-info');
        this.blastDatabaseDropDown = Dom.get('blast-database-option');
        this.blastDatabaseInfo = Dom.get('blast-database-option-info');

        /* --- Algorithm Parameters Elements --- */
        this.eValueDropDown = Dom.get('e-value');
        this.numAlignDropDown = Dom.get('num-align');
        this.wordSizeDropDown = Dom.get('word-size-option');
        this.matrixDropDown = Dom.get('matrix-option');
        this.gappedCheckbox = Dom.get('gapped-alignment');
        this.filterCheckbox = Dom.get('filter-alignment');

        /* --- Other elements --- */
        this.sequenceInput = Dom.get('blast-sequence');
        this.toggleParameters = 'show-parameters';
        this.blastParameters = 'blast-parameters',
        this.warning = Dom.get('run-blast-warning');
        this.blastButtonEl = 'run-blast-button';
        this.resetButtonEl = 'reset-blast-button';
        this.ncbiButtonEl = 'ncbi-blast-button';

        /* --- Programs and Databases available from server --- */
        YAHOO.util.Connect.asyncRequest('GET', '/tools/blast/programs', {
            success: function(obj) {
                try {
                    result = YAHOO.lang.JSON.parse(obj.responseText);
                    this.programs = result;
                    this.renderPrograms();
                }
                catch(e) {
                    this.warning.innerHTML = 'Cannot fetch available programs';
                    Dom.removeClass(this.warning, 'hidden');
                    return;
                };
            },
            failure: this.onFailure,
            scope: this
        });

        YAHOO.util.Connect.asyncRequest('GET', '/tools/blast/databases', {
            success: function(obj) {
                try {
                    result = YAHOO.lang.JSON.parse(obj.responseText);
                    this.databases = result;
                    this.renderDatabases();
                }
                catch(e) {
                    this.warning.innerHTML = 'Cannot fetch available databases';
                    Dom.removeClass(this.warning, 'hidden');
                    return;
                };
            },
            failure: this.onFailure,
            scope: this
        });

        /* --- Blast Parameters --- */
        this.initParameters();
        this.renderButtons();
        this.linkEvent();
    }

    YAHOO.Dicty.BLAST.prototype.onFailure = function(obj) {
        this.warning.innerHTML = '<p>' + obj.statusText + '</p>';
    }

    YAHOO.Dicty.BLAST.prototype.renderPrograms = function(filter) {
        var options = new Array(),
        values = new Array(),
        programs = this.programs;

        filter = filter || '';
        
        options.push('-- Please Select a Program --');
        values.push('unselected');

        for (i in programs) {
            if (programs[i].query_type.match(filter)) {
                options.push(programs[i].name + ' - ' + programs[i].desc);
                values.push(programs[i].name);
            }
        }
        this.initDropdown(this.blastProgramDropDown, options, values);
    }

    YAHOO.Dicty.BLAST.prototype.renderDatabases = function(filter) {
        var options = new Array(),
        values = new Array(),
        databases = this.databases;

        filter = filter || '';

        options.push('-- Please Select a Database --');
        values.push('unselected');

        for (i in databases) {
            if (databases[i].type.match(filter)) {
                options.push(databases[i].desc + ' - ' + databases[i].type);
                values.push(databases[i].name);
            }
        }
        this.initDropdown(this.blastDatabaseDropDown, options, values);
    }

    YAHOO.Dicty.BLAST.prototype.initParameters = function() {
        /* --- e-value selector --- */
        var options = ['1000', '500', '100', '10', '1', '0.1', '0.001', '1e-5', '1e-25', '1e-50', '1e-100'];
        var defaultValue = '0.1';
        this.initDropdown(this.eValueDropDown, options, options, defaultValue);

        /* --- Number of Alignments selector --- */
        options = ['5', '25', '50', '100', '250', '500', '750', '1000'];
        defaultValue = '50';
        this.initDropdown(this.numAlignDropDown, options, options, defaultValue);

        /* --- Word Size selector --- */
        options = ['2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15'];
        defaultValue = '3';
        this.initDropdown(this.wordSizeDropDown, options, options, defaultValue);

        /* --- Matrix selector --- */
        options = ['BLOSUM45', 'BLOSUM62', 'BLOSUM80', 'PAM30', 'PAM70'];
        defaultValue = 'BLOSUM62';
        this.initDropdown(this.matrixDropDown, options, options, defaultValue);

        /* --- Gapped Alignment --- */
        this.gappedCheckbox.checked = true;

        /* --- Filtering --- */
        this.filterCheckbox.checked = true;
    }

    YAHOO.Dicty.BLAST.prototype.renderButtons = function() {
        /* --- Render buttons --- */
        this.blastButton = new YAHOO.widget.Button({
            container: this.blastButtonEl,
            label: 'BLAST',
            type: 'button',
            id: 'run-blast',
            onclick: {
                fn: this.runBlast,
                scope: this
            }
        });

        var resetButton = new YAHOO.widget.Button({
            container: this.resetButtonEl,
            label: 'Reset',
            type: 'button',
            onclick: {
                fn: function() {
                    this.sequenceInput.value = 'Paste your sequence here ......';
                    this.renderPrograms();
                    this.renderDatabases();
                    this.initParameters();
                    Dom.addClass(this.blastProgramInfo, 'hidden');
                    Dom.addClass(this.blastDatabaseInfo, 'hidden');
                    Dom.addClass(this.warning, 'hidden');
/*                    
                    this.blastQueryID.value = '';
                    Dom.addClass(Dom.getAncestorByTagName(this.blastFeatureDropDown, 'div'), 'hidden');
                    Dom.addClass(Dom.getAncestorByTagName(this.blastSequenceDropDown, 'div'), 'hidden');
*/
                },
                scope: this
            }
        });

        var ncbiBlastButton = new YAHOO.widget.Button({
            container: this.ncbiButtonEl,
            label: 'BLAST at NCBI',
            type: 'button',
            onclick: {
                fn: this.runNcbiBlast,
                scope: this
            }
        });
    }

    YAHOO.Dicty.BLAST.prototype.initDropdown = function(el, options, values, defaultValue) {
        var selectedIndex = 0;
        el.options.length = 0;
        for (i in options) {
            if ((defaultValue !== undefined) && (options[i] == defaultValue)) {
                selectedIndex = i;
            }
            el.options[el.options.length] = new Option(options[i], values[i]);
        }
        el[selectedIndex].selected = true;
    }

    YAHOO.Dicty.BLAST.prototype.selectDropdownValue = function(el, value) {
        var selectedIndex = 0;
        YAHOO.log(el.id + value, 'warn');
        for (var i = 0; i < el.options.length; i++) {
            if (el.item(i).value == value) {
                selectedIndex = i;
            }
        }
        el[selectedIndex].selected = true;
    }

    YAHOO.Dicty.BLAST.prototype.linkEvent = function() {
        /* --- Sequence Input field focus listener -- */
        var sequenceInput = this.sequenceInput;
        YAHOO.util.Event.addFocusListener(sequenceInput.id,
        function() {
            var initData = sequenceInput.value;
            if ((initData.match('Paste')) || (initData.match('paste'))) {
                sequenceInput.value = '';
                Dom.removeClass(sequenceInput.id, 'warning');
            };
        });

        /* --- Blast Parameters display trigger -- */
        YAHOO.util.Event.addListener(this.toggleParameters, 'click',
        function(e, obj) {
            if (Dom.hasClass(obj.blastParameters, 'hidden')) {
                Dom.removeClass(obj.blastParameters, 'hidden');
            }
            else {
                Dom.addClass(obj.blastParameters, 'hidden');
            }
        },
        this);

        /* --- On BLAST program change, rest of parameters have to be ajusted --- */
        YAHOO.util.Event.addListener(this.blastProgramDropDown, 'change', this.onProgramChange, this);

        /* --- Warning hiding --- */
        YAHOO.util.Event.addListener(this.blastDatabaseDropDown, 'change',
        function(e, obj) {
            Dom.addClass(obj.blastDatabaseInfo.id, 'hidden');
        },
        this);
    }

    YAHOO.Dicty.BLAST.prototype.onProgramChange = function(e, obj) {
        /* --- If "unselected" value selected, render all available databases --- */
        var selectedIndex = obj.blastProgramDropDown.selectedIndex;
        if (selectedIndex === 0) {
            obj.renderDatabases();
            return;
        }
        /* --- Filter databases based on database type allowed for selected program --- */
        var programs = obj.programs,
        databaseType;

        for (i in programs) {
            if (programs[i].name == obj.blastProgramDropDown[selectedIndex].value) {
                databaseType = programs[i].database_type;
                continue;
            }
        }
        obj.renderDatabases(databaseType);
        obj.selectDropdownValue(obj.blastDatabaseDropDown, 'unselected');

        /* --- Set program dependent default algorithm parameters --- */
        defaultValue = obj.blastProgramDropDown[selectedIndex].value == 'blastn' ? '11': '3';
        obj.selectDropdownValue(obj.wordSizeDropDown, defaultValue);
    }

    YAHOO.Dicty.BLAST.prototype.runBlast = function() {
        Dom.addClass(this.warning.id, 'hidden');
        var valid = this.validateParameters('blast');

        if (valid) {
            var program = this.blastProgramDropDown.options[this.blastProgramDropDown.selectedIndex].value,
            database = this.blastDatabaseDropDown.options[this.blastDatabaseDropDown.selectedIndex].value,
            eValue = this.eValueDropDown.options[this.eValueDropDown.selectedIndex].value,
            numAlign = this.numAlignDropDown.options[this.numAlignDropDown.selectedIndex].value,
            wordSize = this.wordSizeDropDown.options[this.wordSizeDropDown.selectedIndex].value,
            matrix = this.matrixDropDown.options[this.matrixDropDown.selectedIndex].value,
            gapped = this.gappedCheckbox.checked ? 'T': 'F',
            filter = this.filterCheckbox.checked ? 'T': 'F',
            fasta = this.sequenceInput.value;

            if ((database == 'dicty_chromosomal') && (filter == 'F')) {
                if ((program === 'tblastn') || (program === 'tblastx')) {
                    filter = 'm S';
                }
                else {
                    filter = 'm D';
                }
            }
        
            var postData =
            'program=' + program + 
            '&database=' + database +
            '&evalue=' + eValue +
            '&limit=' + numAlign +
            '&wordsize=' + wordSize +
            '&matrix=' + matrix +
            '&gapped=' + gapped +
            '&filter=' + filter +
            '&sequence=' + fasta;

            resultWindow = window.open();
            resultWindow.document.write('Please wait for results to be loaded');
            resultWindow.document.close();

            YAHOO.util.Connect.asyncRequest('POST', '/tools/blast/run',
            {
                success: function(obj) {
                    var results = obj.responseText;
                    if (results.match('BLAST') && !(results.match('Sorry'))) {
                        var form =
                        '<form method="post" name="blast_report" action="/tools/blast/report">' +
                        '<textarea name="report" style="display:none;" >' + results + '</textarea></form>';

                        resultWindow.document.write(form);
                        resultWindow.document.close();
                        resultWindow.document.forms.blast_report.submit();
                    }
                    else {
                        this.warning.innerHTML = results;
                        Dom.removeClass(this.warning.id, 'hidden');
                        resultWindow.document.write(results);
                        resultWindow.document.close();
                    }
                },
                failure: this.onFailure,
                scope: this
            },
            postData);
        }
    }

    YAHOO.Dicty.BLAST.prototype.runNcbiBlast = function() {
        var valid = this.validateParameters('ncbi-blast');
        if (valid) {
            var program = this.blastProgramDropDown.options[this.blastProgramDropDown.selectedIndex].value,
            fasta = this.sequenceInput.value,
            page;

            if ((program == 'tblastn') || (program == 'tblastx') || (program == 'blastx')) {
                page = 'Translations';
            }
            else if (program == 'blastp') {
                page = 'Proteins';
            }
            else {
                page = 'Nucleotides';
            }
            resultWindow = window.open();

            var form =
            '<form method="post" name="ncbi_blast_form" action="http://www.ncbi.nlm.nih.gov/blast/Blast.cgi">' +
            '<input name="PAGE"  type="hidden" value="' + page + '">' +
            '<input name="PROGRAM" type="hidden" value="' + program + '">' +
            '<input name="QUERY"   type="hidden" value="' + fasta + '">' +
            '<input name="FILTER"  type="hidden" value="L"></form>';
            resultWindow.document.write('Please wait while you are redirected to NCBI BLAST.' + form);
            resultWindow.document.forms.ncbi_blast_form.submit();
            resultWindow.document.close();
        }
    }

    YAHOO.Dicty.BLAST.prototype.validateParameters = function(blastType) {
        if (this.sequenceInput.value.match('Paste') || this.sequenceInput.value === '') {
            this.sequenceInput.value = 'Please type or paste a query sequence here';
            Dom.addClass(this.sequenceInput.id, 'warning');
            return false;
        }
        if (this.blastProgramDropDown.selectedIndex === 0) {
            this.blastProgramInfo.innerHTML = 'Please select a program to run';
            Dom.removeClass(this.blastProgramInfo.id, 'hidden');
            return false;
        }
        if (blastType == 'ncbi-blast') {
            return true;
        }
        if (this.blastDatabaseDropDown.options.length > 1 && this.blastDatabaseDropDown.selectedIndex === 0) {
            Dom.removeClass(this.blastDatabaseInfo.id, 'hidden');
            return false;
        }
        return true;
    }

})();

function init() {
    var blast = new YAHOO.Dicty.BLAST;
    blast.init();
}