import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { vi } from 'vitest';
import App from '../App';

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn()
    .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
    .mockResolvedValueOnce(new Response(JSON.stringify({ id: 1, name: 'Avery', email: 'avery@example.com' }), { status: 201 }))
    .mockResolvedValueOnce(new Response(JSON.stringify([{ id: 1, name: 'Avery', email: 'avery@example.com' }]), { status: 200 }))
    .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 })));
});

afterEach(() => vi.unstubAllGlobals());

it('creates a member and displays the selected member', async () => {
  render(<App />);
  await waitFor(() => expect(screen.getByText(/no members yet/i)).toBeInTheDocument());
  fireEvent.change(screen.getByLabelText(/full name/i), { target: { value: 'Avery' } });
  fireEvent.change(screen.getByLabelText(/email address/i), { target: { value: 'avery@example.com' } });
  fireEvent.click(screen.getByRole('button', { name: /create member/i }));
  await waitFor(() => expect(screen.getByRole('button', { name: /avery/i })).toBeInTheDocument());
  expect(screen.queryByRole('alert')).not.toBeInTheDocument();
});
