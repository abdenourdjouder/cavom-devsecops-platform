import { useCallback, useEffect, useState } from 'react';
import { api } from './api';

const emptyMember = { name: '', email: '' };
const emptyContribution = { amount: '', description: '', contributedOn: '' };

function Field({ label, ...props }) {
  return (
    <label>
      <span>{label}</span>
      <input {...props} />
    </label>
  );
}

export default function App() {
  const [members, setMembers] = useState([]);
  const [selected, setSelected] = useState(null);
  const [contributions, setContributions] = useState([]);
  const [member, setMember] = useState(emptyMember);
  const [contribution, setContribution] = useState(emptyContribution);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const loadMembers = useCallback(async () => {
    try {
      setMembers(await api.members());
      setError('');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadMembers(); }, [loadMembers]);

  async function selectMember(id) {
    setSelected(id);
    setError('');
    try {
      setContributions(await api.contributions(id));
    } catch (err) {
      setContributions([]);
      setError(err.message);
    }
  }

  async function addMember(event) {
    event.preventDefault();
    setError('');
    try {
      const created = await api.createMember(member);
      setMember(emptyMember);
      await loadMembers();
      await selectMember(created.id);
    } catch (err) {
      setError(err.message);
    }
  }

  async function addContribution(event) {
    event.preventDefault();
    setError('');
    try {
      await api.createContribution(selected, {
        ...contribution,
        amount: Number(contribution.amount)
      });
      setContribution(emptyContribution);
      await selectMember(selected);
    } catch (err) {
      setError(err.message);
    }
  }

  const total = contributions.reduce((sum, item) => sum + Number(item.amount), 0);

  return (
    <main>
      <header>
        <p className="eyebrow">CAVOM COMMUNITY</p>
        <h1>Members & contributions</h1>
        <p>One clear place to manage the people and support behind your community.</p>
      </header>

      {error && <div className="error" role="alert">{error}</div>}

      <section className="layout">
        <div className="panel">
          <h2>Add a member</h2>
          <form onSubmit={addMember}>
            <Field label="Full name" value={member.name} required maxLength="100"
              onChange={(e) => setMember({ ...member, name: e.target.value })} />
            <Field label="Email address" type="email" value={member.email} required maxLength="254"
              onChange={(e) => setMember({ ...member, email: e.target.value })} />
            <button type="submit">Create member</button>
          </form>
        </div>

        <div className="panel roster">
          <h2>Member directory <span>{members.length}</span></h2>
          {loading ? <p>Loading members…</p> : (
            <div className="member-list">
              {members.length === 0 && <p>No members yet. Add the first one.</p>}
              {members.map((item) => (
                <button className={selected === item.id ? 'member active' : 'member'}
                  key={item.id} onClick={() => selectMember(item.id)}>
                  <strong>{item.name}</strong>
                  <small>{item.email}</small>
                </button>
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="panel contributions">
        <div className="section-heading">
          <div><p className="eyebrow">CONTRIBUTIONS</p><h2>Support history</h2></div>
          {selected && <strong className="total">{new Intl.NumberFormat('en', {
            style: 'currency', currency: 'USD'
          }).format(total)} total</strong>}
        </div>
        {!selected ? <p className="empty">Select a member to view and record contributions.</p> : (
          <>
            <form className="contribution-form" onSubmit={addContribution}>
              <Field label="Amount" type="number" min="0.01" step="0.01" required value={contribution.amount}
                onChange={(e) => setContribution({ ...contribution, amount: e.target.value })} />
              <Field label="Description" required maxLength="255" value={contribution.description}
                onChange={(e) => setContribution({ ...contribution, description: e.target.value })} />
              <Field label="Date" type="date" required value={contribution.contributedOn}
                onChange={(e) => setContribution({ ...contribution, contributedOn: e.target.value })} />
              <button type="submit">Record</button>
            </form>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Date</th><th>Description</th><th>Amount</th></tr></thead>
                <tbody>
                  {contributions.length === 0 && <tr><td colSpan="3" className="empty">No contributions recorded.</td></tr>}
                  {contributions.map((item) => (
                    <tr key={item.id}><td>{item.contributedOn}</td><td>{item.description}</td>
                      <td>${Number(item.amount).toFixed(2)}</td></tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>
    </main>
  );
}
