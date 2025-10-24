const app = document.getElementById('app');
const closeBtn = document.getElementById('close-btn');
const salaryContainer = document.getElementById('salary-container');
const storeContainer = document.getElementById('store-container');
const allocationContainer = document.getElementById('allocation-container');
const taxForm = document.getElementById('tax-form');
const taxAmountInput = document.getElementById('tax-amount');
const taxIntervalInput = document.getElementById('tax-interval');

let state = null;

function nuiCallback(action, data = {}) {
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function clearContainers() {
    salaryContainer.innerHTML = '';
    storeContainer.innerHTML = '';
    allocationContainer.innerHTML = '';
}

function renderSalaries() {
    const jobs = state.config.payManagedJobs;
    const salaries = state.salaries;

    Object.entries(jobs).forEach(([jobName, data]) => {
        const fieldset = document.createElement('fieldset');
        const legend = document.createElement('legend');
        legend.textContent = data.label;
        fieldset.appendChild(legend);

        data.grades.forEach((grade) => {
            const wrapper = document.createElement('div');
            wrapper.classList.add('grade-row');

            const label = document.createElement('label');
            label.textContent = `${grade.label} (Grade ${grade.grade})`;

            const input = document.createElement('input');
            input.type = 'number';
            input.min = state.config.salaryLimits.minimum;
            input.max = state.config.salaryLimits.maximum;
            input.step = '1';
            input.value = salaries[jobName]?.[String(grade.grade)] ?? grade.salary;

            const button = document.createElement('button');
            button.type = 'button';
            button.textContent = 'Mentés';

            button.addEventListener('click', () => {
                nuiCallback('updateSalary', {
                    jobName,
                    grade: grade.grade,
                    salary: Number(input.value)
                });
            });

            wrapper.appendChild(label);
            wrapper.appendChild(input);
            wrapper.appendChild(button);
            fieldset.appendChild(wrapper);
        });

        salaryContainer.appendChild(fieldset);
    });
}

function renderStores() {
    const categories = state.config.storeCategories;
    const storePrices = state.storePrices;

    Object.entries(categories).forEach(([category, data]) => {
        const fieldset = document.createElement('fieldset');
        const legend = document.createElement('legend');
        legend.textContent = data.label;
        fieldset.appendChild(legend);

        const description = document.createElement('p');
        description.classList.add('hint');
        description.textContent = data.description || '';
        fieldset.appendChild(description);

        const input = document.createElement('input');
        input.type = 'number';
        input.step = '0.01';
        input.min = data.minimum ?? 0;
        input.max = data.maximum ?? 100;
        input.value = (storePrices[category] ?? data.multiplier ?? 1).toFixed(2);

        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = 'Szorzó mentése';
        button.addEventListener('click', () => {
            nuiCallback('updateStorePrice', {
                category,
                multiplier: Number(input.value)
            });
        });

        fieldset.appendChild(input);
        fieldset.appendChild(button);
        storeContainer.appendChild(fieldset);
    });
}

function renderAllocations() {
    const allocations = state.config.allocations;
    const current = state.allocations;

    Object.entries(allocations).forEach(([jobName, data]) => {
        const fieldset = document.createElement('fieldset');
        const legend = document.createElement('legend');
        legend.textContent = data.label;
        fieldset.appendChild(legend);

        const input = document.createElement('input');
        input.type = 'number';
        input.min = '0';
        input.step = '100';
        input.value = Math.floor(current[jobName] ?? data.amount);

        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = 'Napi keret mentése';
        button.addEventListener('click', () => {
            nuiCallback('updateAllocation', {
                jobName,
                amount: Number(input.value)
            });
        });

        fieldset.appendChild(input);
        fieldset.appendChild(button);
        allocationContainer.appendChild(fieldset);
    });
}

function renderTax() {
    taxAmountInput.value = Math.floor(state.tax.amount ?? state.config.defaultTax.amount);
    taxIntervalInput.value = Math.floor(state.tax.interval ?? state.config.defaultTax.intervalMinutes);
}

function render(payload) {
    state = payload;
    clearContainers();
    renderSalaries();
    renderStores();
    renderAllocations();
    renderTax();
    app.classList.remove('hidden');
}

window.addEventListener('message', (event) => {
    const { type, payload } = event.data;
    if (type === 'open') {
        render(payload);
    } else if (type === 'refresh' && state) {
        render(payload);
    }
});

closeBtn.addEventListener('click', () => {
    app.classList.add('hidden');
    nuiCallback('close');
});

taxForm.addEventListener('submit', (event) => {
    event.preventDefault();
    nuiCallback('updateTax', {
        amount: Number(taxAmountInput.value),
        interval: Number(taxIntervalInput.value)
    });
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape') {
        app.classList.add('hidden');
        nuiCallback('close');
    }
});
