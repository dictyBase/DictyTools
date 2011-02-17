(function() {
    YAHOO.namespace('Dicty');
    var Dom = YAHOO.util.Dom;
    var Event = YAHOO.util.Event;
    var pasteYourSeq = 'Type or paste a query sequence here ......';
    
    YAHOO.Dicty.BLAST = function() {
//       var logger = new YAHOO.widget.LogReader();
    };

    YAHOO.lang.augmentProto(YAHOO.Dicty.BLAST, YAHOO.util.AttributeProvider);

    YAHOO.Dicty.BLAST.prototype.init = function() {
        /* --- BLAST Controls --- */
        this.blastProgramDropDown = Dom.get('blast-program-option');
        this.blastProgramInfo = Dom.get('blast-program-option-info');
        this.blastDatabaseDropDown = Dom.get('blast-database-option');
        this.blastDatabaseInfo = Dom.get('blast-database-option-info');
        this.blastOrganismDropDown = Dom.get('blast-organism-option');
        
        /* --- CUSTOM PART--- */        
        this.blastFeatureDropDown = Dom.get('blast-feature-option');
        this.blastSequenceDropDown = Dom.get('blast-sequence-option');
        this.blastQueryID = Dom.get('query-primary-id');
        this.blastIDInputInfo = Dom.get('blast-id-selection-warn');
        /* --- END OF CUSTOM PART--- */  
        
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
        this.blastParameters = 'blast-parameters';
        this.warning = Dom.get('run-blast-warning');
        this.blastButtonEl = 'run-blast-button';
        this.resetButtonEl = 'reset-blast-button';
        this.ncbiButtonEl = 'ncbi-blast-button';
        
        this.mainForm = Dom.get('blast-form');

        /* --- Programs and Databases available from server --- */
        YAHOO.util.Connect.asyncRequest('GET', '/tools/blast/programs', {
            success: function(obj) {
                try {
                    this.programs = YAHOO.lang.JSON.parse(obj.responseText);
                    this.renderPrograms();
                }
                catch(e) {
                    this.warning.innerHTML = 'Cannot fetch available programs';
                    Dom.removeClass(this.warning, 'hidden');
                    return;
                }
            },
            failure: this.onFailure,
            scope: this
        });

        YAHOO.util.Connect.asyncRequest('GET', '/tools/blast/databases', {
            success: function(obj) {
                try {
                    this.databases = YAHOO.lang.JSON.parse(obj.responseText);
                }
                catch(e) {
                    this.warning.innerHTML = 'Cannot fetch available databases';
                    Dom.removeClass(this.warning, 'hidden');
                    return;
                }
            },
            failure: this.onFailure,
            scope: this
        });

        /* --- CUSTOM PART--- */  
        /* --- Get list of identifier prefixes from server --- */
        YAHOO.util.Connect.asyncRequest('GET', '/tools/organism', {
            success: function(obj) {
                try {
                    this.organisms = YAHOO.lang.JSON.parse(obj.responseText);
                    this.renderOrganisms();
                    this.renderDatabases();
                    // --- if query id is already set, start search ---
                    if (this.blastQueryID.value !== ''){
                        this.translate(this.blastQueryID.value);
                    }
                }
                catch(e) {
                    this.warning.innerHTML = 'Cannot fetch available organisms';
                    Dom.removeClass(this.warning, 'hidden');
                    return;
                }
            },
            failure: this.onFailure,
            scope: this
        });
        /* --- END OF CUSTOM PART--- */  
        
        /* --- Blast Parameters --- */
        this.initParameters();
        this.renderButtons();
        this.linkEvent();
        
    };

    YAHOO.Dicty.BLAST.prototype.onFailure = function(obj) {
        //this.warning.innerHTML = '<p>' + obj.statusText + '</p>';
//        alert(obj.statusText);
    };

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
        databases = this.databases,
        programs = this.programs,
        type;

        var selectedIndex = this.blastProgramDropDown.selectedIndex;
        for (i in programs) {
            if (programs[i].name == this.blastProgramDropDown[selectedIndex].value) {
                type = programs[i].database_type;
                continue;
            }
        }
        if (!type || type.match('unselected')){
            type = '';
        } 
        
        var organism = this.blastOrganismDropDown.options[this.blastOrganismDropDown.selectedIndex].value;
        if (organism.match('unselected')){
            organism = '';
        }
    
        for (i in databases) {
            if (databases[i].type.match(type) && databases[i].desc.match(organism)) {
                options.push(databases[i].desc + ' - ' + databases[i].type);
                values.push(databases[i].name);
            }
        }
        if (options.length > 1){
            options.unshift('-- Please Select a Database --');
            values.unshift('unselected');
        }
        this.initDropdown(this.blastDatabaseDropDown, options, values);
    }
    
    YAHOO.Dicty.BLAST.prototype.renderOrganisms = function() {
        var options = new Array(),
        values = new Array(),
        organisms = this.organisms;

        options.push('-- Please Select an Organism --');
        values.push('unselected');

        function compareOrganisms(a, b) {
            var genusA = a.genus || '', 
                genusB = b.genus || '',
                nameA = genusA + ' ' + a.species,
                nameB = genusB + ' ' + b.species;
                
            if (nameA < nameB) {return -1}
            if (nameA > nameB) {return 1}
            return 0;
        }

        for (i in organisms.sort(compareOrganisms)) {
            var genus = organisms[i].genus ? organisms[i].genus : '';
            options.push( genus + ' ' + organisms[i].species);
            values.push(organisms[i].species);
        }
        this.initDropdown(this.blastOrganismDropDown, options, values);
        this.selectDropdownValue(this.blastOrganismDropDown, 'discoideum');
    }
    
    /* --- CUSTOM PART--- */  
    YAHOO.Dicty.BLAST.prototype.renderFeatureDropDown = function(data) {
        Dom.addClass(this.blastIDInputInfo.id, 'hidden');
        var el = this.blastFeatureDropDown;
        
        el.options.length = 0;
        if (data.length == 1) {
            el.options[el.options.length] = new Option(data[0].id + ' - ' + data[0].description, data[0].id);
            el.options.item(0).selected = true;
            this.translate(data[0].id);
        }
        else {
            el.options[el.options.length] = new Option('-- Please Select a Sequence --', 'unselected');
            for (i in data) {
                el.options[el.options.length] = new Option(data[i].id + ' - ' + data[i].description, data[i].id);
            }
        }
        var parent = Dom.getAncestorByTagName(el, 'div');
        Dom.removeClass(parent, 'hidden');
    }

    YAHOO.Dicty.BLAST.prototype.renderSequnceDropdown = function(data) {
        var el = this.blastSequenceDropDown,
            prefilledSequence = el.options.length > 0 ? el.options.item(0).innerHTML: '',
            id = this.blastFeatureDropDown.options[this.blastFeatureDropDown.selectedIndex].value || this.blastQueryID.value;

        el.options.length = 0;

        if (data.length == 1) {
            this.requestSequence(id, data[0]);
        }
        else {
            el.options[el.options.length] = new Option('-- Please Select a Sequence Type--', 'unselected');
                    
            var selectedIndex = 0;
            var i;
            for (i in data) {
                if ((prefilledSequence !== '') && (data[i].match(prefilledSequence))) {
                    selectedIndex = i;
                    selectedIndex++;                   
                    this.requestSequence(id, data[i]);
                }
                el.options[el.options.length] = new Option(data[i], data[i]);
            }

            el.options.item(selectedIndex).selected = true;
            var parent = Dom.getAncestorByTagName(el, 'div');

            if (prefilledSequence !== '') {
                var filter = prefilledSequence.match('Protein') ? 'protein': 'DNA';
                this.renderPrograms(filter);
                this.renderDatabases(filter);
                
                var defaultProgram = prefilledSequence.match('Protein') ? 'blastp': 'blastn';
                this.selectDropdownValue(this.blastProgramDropDown, defaultProgram);
                this.renderDatabases();
                //var defaultDatabase =
                //prefilledSequence.match('Genomic') ? 'dictyBase Genomic Sequences - DNA':
                //prefilledSequence.match('coding') || prefilledSequence.match('transcript') ? 'dictyBase Coding Sequences - DNA': 'unselected';
                //adjustDatabaseDropdown(defaultProgram);
                //selectDropDown(blastDatabaseDropDown, defaultDatabase);
                //defaultValue = defaultProgram == 'blastn' ? '11': '3';
                //selectDropDown(wordSizeDropDown, defaultValue);
            }
            Dom.removeClass(parent, 'hidden');
        }        
    }
    /* --- END OF CUSTOM PART--- */  

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
                    this.sequenceInput.value = pasteYourSeq;
                    this.renderPrograms();
                    this.renderOrganisms();
                    this.renderDatabases();
                    this.initParameters();
                    Dom.addClass(this.blastProgramInfo, 'hidden');
                    Dom.addClass(this.blastDatabaseInfo, 'hidden');
                    Dom.addClass(this.warning, 'hidden');
                    Dom.removeClass(this.sequenceInput, 'warning')
                    
                    this.blastQueryID.value = '';
                    Dom.addClass(Dom.getAncestorByTagName(this.blastFeatureDropDown, 'div'), 'hidden');
                    Dom.addClass(Dom.getAncestorByTagName(this.blastSequenceDropDown, 'div'), 'hidden');

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
        if (el[selectedIndex] != null){
            el[selectedIndex].selected = true;
        }
    }

    YAHOO.Dicty.BLAST.prototype.selectDropdownValue = function(el, value) {
        var selectedIndex = 0;
        //YAHOO.log(el.id + value, 'warn');
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
        
        /* --- on organism change filter database list --- */
        YAHOO.util.Event.addListener(this.blastOrganismDropDown, 'change',
        function(e, obj) {
           //var filter = obj.blastOrganismDropDown.options[obj.blastOrganismDropDown.selectedIndex].value;
           obj.renderDatabases();
        },
        this);
        
        /* --- Warning hiding --- */
        YAHOO.util.Event.addListener(this.blastDatabaseDropDown, 'change',
        function(e, obj) {
            Dom.addClass(obj.blastDatabaseInfo.id, 'hidden');
        },
        this);
        

        /* --- CUSTOM PART--- */          
        /* --- Searching by id --- */
        YAHOO.util.Event.addListener('submit-primary-id', 'click',
        function(e, obj) {
            // --- Hide sequence and feature dropdowns, remove warnings and clean sequence input field ---
            Dom.addClass(Dom.getAncestorByTagName(obj.blastSequenceDropDown, 'div'), 'hidden');
            Dom.addClass(Dom.getAncestorByTagName(obj.blastFeatureDropDown, 'div'), 'hidden');
            Dom.addClass(obj.blastIDInputInfo.id, 'hidden');

            obj.blastIDInputInfo.innerHTML = '';
            obj.sequenceInput.value = pasteYourSeq;
            obj.translate(obj.blastQueryID.value);
        },
        this);

        YAHOO.util.Event.addListener(this.blastFeatureDropDown, 'change',
        function(e, obj){
            var index = obj.blastFeatureDropDown.selectedIndex,
            id = obj.blastFeatureDropDown.options[index].value;

            Dom.addClass(Dom.getAncestorByTagName(obj.blastSequenceDropDown, 'div'), 'hidden');
            Dom.addClass('blast-id-selection-warn', 'hidden');

            if (id == 'unselected') {
                return;
            }
            obj.translate(id);
        },
        this);

        YAHOO.util.Event.addListener(this.blastSequenceDropDown, 'change',
        function(e, obj){
            var id = obj.blastFeatureDropDown.options[obj.blastFeatureDropDown.selectedIndex].value || obj.blastQueryID.value;
                type = obj.blastSequenceDropDown.options[obj.blastSequenceDropDown.selectedIndex].value;
                
                if (type == 'unselected') {
                    // --- clean up all filters//selections done based on sequence type ---
                    obj.sequenceInput.value = pasteYourSeq;
                    obj.renderPrograms();
                    obj.renderDatabases();
                    return;
                }
                // --- filter programs and databases based on sequence type --- 
                var filter = type.match('Protein') ? 'protein' : 'DNA';
                obj.renderPrograms(filter);
                obj.renderDatabases(filter);
                
                //--- set up default program to run based on sequence type --- 
                var defaultProgram = type.match('Protein') ? 'blastp': 'blastn';
                obj.selectDropdownValue(obj.blastProgramDropDown, defaultProgram);
                
                var defaultValue = defaultProgram == 'blastn' ? '11': '3';
                obj.selectDropdownValue(obj.wordSizeDropDown, defaultValue);
                //YAHOO.log('here','error');
                obj.requestSequence(id,type);
                obj.renderDatabases();
        },
        this);

        YAHOO.util.Event.addListener(this.blastProgramDropDown, 'change',
        function(e, obj) {
            Dom.addClass(obj.blastProgramInfo.id, 'hidden');
        },
        this);
        /* --- END OF CUSTOM PART--- */  
    }

    YAHOO.Dicty.BLAST.prototype.onProgramChange = function(e, obj) {
        /* --- If "unselected" value selected, render all available databases --- */
        var selectedIndex = obj.blastProgramDropDown.selectedIndex;
        obj.renderDatabases();
        
        /* --- Set program dependent default algorithm parameters --- */
        var defaultValue = obj.blastProgramDropDown[selectedIndex].value == 'blastn' ? '11': '3';
        obj.selectDropdownValue(obj.wordSizeDropDown, defaultValue);
    }

    YAHOO.Dicty.BLAST.prototype.runBlast = function(e) {
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
        
            var postData = encodeURI(
            'program=' + program + 
            '&database=' + database +
            '&evalue=' + eValue +
            '&limit=' + numAlign +
            '&wordsize=' + wordSize +
            '&matrix=' + matrix +
            '&gapped=' + gapped +
            '&filter=' + filter +
            '&sequence=' + fasta);
          
            var resultWindow = window.open();
            resultWindow.document.write('Please wait for results to be loaded');
            resultWindow.document.close();
                        
            // send multiform post. 
            YAHOO.util.Connect.setForm(this.mainForm.id, true, true);            
            YAHOO.util.Connect.asyncRequest('POST', this.mainForm.action,
            {
                upload: function(obj) {
                    // have to do it twice: for some reason in ie <pre.+?>|<\/pre> gerex wipes out whole string
                    var results_file = obj.responseText.replace(/<pre>|<\/pre>/ig,'');
                    if (results_file.match(/pre/i)){
                        results_file = results_file.replace(/<pre.+?>|<\/pre>/ig,'');
                    }
                    if (results_file.match(/sorry|exception|unavailable/i)){
                        this.warning.innerHTML = results_file;
                        Dom.addClass(this.warning.id, 'warning');
                        Dom.removeClass(this.warning.id, 'hidden');
                        
                        resultWindow.document.write(results_file);
                        resultWindow.document.close();
                    }
                    else {
                        this.results_file = results_file;
                        this.renderResultsWindow(resultWindow);
                    }
                },
                failure: this.onFailure,
                scope: this
            }, postData);
        }
    }
    
    YAHOO.Dicty.BLAST.prototype.renderResultsWindow = function(resultWindow) {
        Dom.addClass(this.warning.id, 'warning');
        Dom.addClass(this.warning.id, 'hidden');

        var form = '<form method="post" name="blast_report" action="/tools/blast/report">' +
            '<input name="report_file" style="display:none;" value="' + this.results_file + '"></input>'+
            '</form>'; 
          
        resultWindow.document.write(form);
        resultWindow.document.close();
        resultWindow.document.forms.blast_report.submit();         
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
        if (this.sequenceInput.value.match('paste') || this.sequenceInput.value.match('wait') || this.sequenceInput.value === '') {
            this.sequenceInput.value = pasteYourSeq;
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
    
    /* --- CUSTOM PART--- */  
    YAHOO.Dicty.BLAST.prototype.translate = function(queryID) {
        var postData,
        request;

        for (i in this.organisms) {
            if (this.organisms[i].identifier_prefix == undefined) { continue; }
            
                if (queryID.match(this.organisms[i].identifier_prefix + '_G')) {
                postData = 'from=' + 'gene' + '&to=' + 'features' + '&ids=' + queryID + '&organism=' + this.organisms[i].species;
                
                request = YAHOO.util.Connect.asyncRequest('POST', '/tools/converter',
                {
                    success: function(obj) {
                        try {
                            var results = YAHOO.lang.JSON.parse(obj.responseText);
                        }
                        catch(e) {
                            this.blastIDInputInfo.innerHTML = 'Please provide valid ID';
                            Dom.removeClass(this.blastIDInputInfo.id, 'hidden');
                            return;
                        }
                        this.renderFeatureDropDown(results);
                    },
                    failure: this.onFailure,
                    scope: this
                },
                postData);
                break;
            }
            else if (queryID.match(this.organisms[i].identifier_prefix)) {
                postData = 'from=' + 'feature' + '&to=' + 'seqtypes' + '&ids=' + queryID + '&organism=' + this.organisms[i].species;
                request = YAHOO.util.Connect.asyncRequest('POST', '/tools/converter',
                {
                    success: function(obj) {
                        try {
                            var results = YAHOO.lang.JSON.parse(obj.responseText);
                        }
                        catch(e) {
                            this.blastIDInputInfo.innerHTML = 'Please provide valid ID';
                            Dom.removeClass(this.blastIDInputInfo.id, 'hidden');
                            return;
                        }
                        this.renderSequnceDropdown(results);
                    },
                    failure: this.onFailure,
                    scope: this
                },
                postData);
                break;
            }
        }
        if (postData == undefined) {
            this.blastIDInputInfo.innerHTML = 'Provided ID does not belong to any known organism';
            Dom.removeClass(this.blastIDInputInfo.id, 'hidden');
        }
    }

    YAHOO.Dicty.BLAST.prototype.requestSequence = function(id, type) {
        this.sequenceInput.value = 'Please wait for the sequence to be populated...';
        //--- contains hardcoded site name ---
        for (i in this.organisms) {
            if (id.match(this.organisms[i].identifier_prefix)) {
                var postData = 'id=' + id + '&type=' + type  + '&organism=' + this.organisms[i].species;
                var request = YAHOO.util.Connect.asyncRequest('POST', '/tools/fasta', 
                {
                    success: function(obj) {
                        this.sequenceInput.value = obj.responseText;
                        Dom.removeClass(this.sequenceInput, 'warning');    
                    },
                    failure: this.onFailure,
                    scope: this            
                }, 
                postData);
            }
        }
    }
    /* --- END OF CUSTOM PART--- */  
    
})();

function initBlast() {
    var blast = new YAHOO.Dicty.BLAST;
    blast.init();
}
