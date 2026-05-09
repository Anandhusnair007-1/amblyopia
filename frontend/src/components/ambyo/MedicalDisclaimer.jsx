import React from 'react';
import { AlertTriangle } from 'lucide-react';

/**
 * Hospital-grade Medical Disclaimer Component
 * Required for all patient and doctor screening results.
 */
const MedicalDisclaimer = ({ variant = 'standard' }) => {
  if (variant === 'mini') {
    return (
      <div className="flex items-center gap-2 p-2 rounded-lg bg-amber-50 border border-amber-100 text-[10px] text-amber-800 leading-tight">
        <AlertTriangle size={12} className="flex-shrink-0" />
        <p>Screening support only. Not an autonomous diagnosis. Final confirmation by MD/Optom required.</p>
      </div>
    );
  }

  return (
    <div className="p-4 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 shadow-sm my-4">
      <div className="flex items-center gap-3 mb-2">
        <div className="p-2 rounded-full bg-amber-100 text-amber-600">
          <AlertTriangle size={20} />
        </div>
        <h4 className="font-bold text-sm uppercase tracking-wider">Clinical Disclaimer</h4>
      </div>
      <div className="space-y-2 text-xs md:text-sm leading-relaxed opacity-90">
        <p>
          <strong>AmbyoAI</strong> is an AI-assisted screening and referral decision-support system. 
          It is <strong>NOT</strong> an autonomous diagnostic device.
        </p>
        <ul className="list-disc pl-5 space-y-1">
          <li>All results must be clinically verified by a qualified ophthalmologist or optometrist.</li>
          <li>Final diagnosis, treatment plan, and surgical decisions are the sole responsibility of the attending clinician.</li>
          <li>AI predictions depend on image quality and patient cooperation.</li>
        </ul>
        <p className="pt-2 italic text-[10px] border-t border-amber-200/50">
          Protocol: V-DISC-2026-HOSPITAL
        </p>
      </div>
    </div>
  );
};

export default MedicalDisclaimer;
