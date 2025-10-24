Config = {}

Config.GovernmentJob = {
    name = 'government',
    minimumGrade = 4,
    society = 'society_government'
}

Config.SalaryLimits = {
    minimum = 50,
    maximum = 5000
}

Config.PayManagedJobs = {
    ambulance = {
        label = 'Ambulance',
        grades = {
            { grade = 0, label = 'Mentő gyakornok', salary = 600 },
            { grade = 1, label = 'Mentő', salary = 800 },
            { grade = 2, label = 'Mentőtiszt', salary = 950 },
            { grade = 3, label = 'Mentővezető', salary = 1100 }
        }
    },
    police = {
        label = 'Rendőrség',
        grades = {
            { grade = 0, label = 'Kadét', salary = 750 },
            { grade = 1, label = 'Járőr', salary = 900 },
            { grade = 2, label = 'Őrmester', salary = 1100 },
            { grade = 3, label = 'Felügyelő', salary = 1300 }
        }
    },
    bcso = {
        label = 'BCSO',
        grades = {
            { grade = 0, label = 'Deputy', salary = 700 },
            { grade = 1, label = 'Deputy II', salary = 850 },
            { grade = 2, label = 'Őrmester', salary = 1050 },
            { grade = 3, label = 'Részlegvezető', salary = 1250 }
        }
    },
    army = {
        label = 'Hadsereg',
        grades = {
            { grade = 0, label = 'Közkatona', salary = 800 },
            { grade = 1, label = 'Őrmester', salary = 1000 },
            { grade = 2, label = 'Zászlós', salary = 1200 },
            { grade = 3, label = 'Százados', salary = 1400 }
        }
    },
    mechanic = {
        label = 'Szerelők',
        grades = {
            { grade = 0, label = 'Gyakornok', salary = 550 },
            { grade = 1, label = 'Szerelő', salary = 700 },
            { grade = 2, label = 'Vezető szerelő', salary = 900 },
            { grade = 3, label = 'Műhelyvezető', salary = 1100 }
        }
    }
}

Config.StoreCategories = {
    auto_dealer = {
        label = 'Autó kereskedés',
        description = 'Általános jármű ár szorzója a kereskedésekhez.',
        multiplier = 1.0,
        minimum = 0.5,
        maximum = 3.0
    },
    general_store = {
        label = 'Bolt',
        description = 'Alapvető fogyasztási cikkek ár szorzója.',
        multiplier = 1.0,
        minimum = 0.5,
        maximum = 3.0
    },
    wages = {
        label = 'Fizetések adója',
        description = 'Globális fizetés levonás szorzó (0.0 - 1.5).',
        multiplier = 1.0,
        minimum = 0.0,
        maximum = 1.5
    }
}

Config.DailyAllocations = {
    ambulance = {
        label = 'Ambulance',
        amount = 20000
    },
    police = {
        label = 'Rendőrség',
        amount = 20000
    },
    bcso = {
        label = 'BCSO',
        amount = 20000
    },
    mechanic = {
        label = 'Szerelők',
        amount = 15000
    },
    army = {
        label = 'Hadsereg',
        amount = 25000
    }
}

Config.DefaultTax = {
    amount = 400,
    intervalMinutes = 120,
    label = 'Állami adó'
}

Config.AllocationIntervalMinutes = 1440

